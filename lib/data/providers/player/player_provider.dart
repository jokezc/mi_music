import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/cmd_commands.dart';
import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:mi_music/data/cache/music_cache.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/i_player_controller.dart';
import 'package:mi_music/data/providers/player/local_player_controller.dart';
import 'package:mi_music/data/providers/player/player_state.dart';
import 'package:mi_music/data/providers/player/remote_player_controller.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';
import 'package:mi_music/data/providers/settings_provider.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';
import 'package:mi_music/data/providers/system_provider.dart';
import 'package:mi_music/data/services/audio_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mi_music/core/constants/strings_zh.dart';

part 'player_provider.g.dart';

final _logger = Logger();

/// AudioHandler 单例（延迟初始化，避免在 WidgetsFlutterBinding 前执行）
Future<MyAudioHandler>? _audioHandlerSingleton;

Future<MyAudioHandler> _getAudioHandler() async {
  if (_audioHandlerSingleton != null) {
    try {
      return await _audioHandlerSingleton!;
    } catch (e) {
      // 如果之前的初始化失败了，清空单例以便重试
      _logger.e("获取 AudioHandler 单例失败: $e");
      _audioHandlerSingleton = null;
    }
  }

  _audioHandlerSingleton = AudioService.init(
    builder: () => MyAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'cn.jokeo.mi_music.channel.audio',
      androidNotificationChannelName: S.appName,
      // 通知是否常驻
      // 注意：当 androidStopForegroundOnPause: false 时，服务保持前台，通知默认就是常驻的。
      // 此时必须设为 false 以通过断言检查 (!androidNotificationOngoing || androidStopForegroundOnPause)
      androidNotificationOngoing: false,
      
      // 暂停时是否停止前台服务（保持前台以防止在 MIUI 上被杀）
      // 虽然理论上 false 更保活，但在某些设备上（如 MIUI），如果强制前台可能导致通知行为异常或被系统特殊处理。
      androidStopForegroundOnPause: true,
    ),
  );

  try {
    return await _audioHandlerSingleton!;
  } catch (e) {
    _logger.e("初始化 AudioHandler 失败: $e");
    _audioHandlerSingleton = null; // 初始化失败，允许下次调用重试
    rethrow;
  }
}

/// 音频处理器 Provider（复用全局单例，增加日志与超时防止卡死）
@riverpod
Future<MyAudioHandler> audioHandler(Ref ref) async {
  try {
    return await _getAudioHandler().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        throw Exception('AudioService 初始化超时');
      },
    );
  } catch (e, st) {
    _logger.e('audioHandler init failed: $e stackTrace: $st');
    rethrow;
  }
}

/// 统一播放控制器
@riverpod
class UnifiedPlayerController extends _$UnifiedPlayerController {
  IPlayerController? _playerController;
  Timer? _playSongDebounceTimer;
  String? _pendingSongName;
  String? _pendingPlaylistName;
  Timer? _saveStateDebounceTimer;
  int _lastPersistedPositionSeconds = -1;
  bool? _lastPersistedIsPlaying;
  String? _lastPersistedSong;
  LoopMode? _lastPersistedLoopMode;
  bool? _lastPersistedShuffleMode;

  // 生命周期/竞态控制
  bool _disposeHookRegistered = false;
  int _controllerGen = 0; // 控制器绑定代际：重建/切换设备时递增，用于丢弃旧回调
  int _switchGen = 0; // 设备切换代际：防止并发切换时旧流程覆盖新流程
  String? _boundDid; // 当前控制器绑定的 did（remote: 设备 did；local: web_device）
  DeviceType? _boundDeviceType; // 当前控制器绑定的设备类型

  void _ensureDisposeHook() {
    if (_disposeHookRegistered) return;
    _disposeHookRegistered = true;
    ref.onDispose(_onDispose);
  }

  void _onDispose() {
    try {
      // 销毁前：仅本地模式需要强制落盘（远程不做本地持久化）
      final currentState = state.hasValue ? state.value : null;
      if (currentState != null && currentState.currentDevice?.type == DeviceType.local) {
        _saveStateDebounceTimer?.cancel();
        try {
          unawaited(savePlayerState());
        } catch (e) {
          _logger.e('保存播放状态失败: $e');
        }
      }

      _playSongDebounceTimer?.cancel();
      _saveStateDebounceTimer?.cancel();

      // 重要：dispose 走异步，但 onDispose 不会 await；这里用 unawaited 丢到后台收尾
      final controller = _playerController;
      _playerController = null;
      unawaited(controller?.dispose() ?? Future.value());
    } catch (e) {
      _logger.e('UnifiedPlayerController dispose 错误: $e');
    }
  }

  Future<void> _bindControllerCallback(Device? currentDevice) async {
    // 每次初始化（包括 remote->remote 切换 did）都重新绑定一次回调，严格校验 did + 代际，防止串台
    _controllerGen++;
    final gen = _controllerGen;
    _boundDid = currentDevice?.did;
    _boundDeviceType = currentDevice?.type;

    await _playerController?.setStateUpdateCallback((newState) {
      if (!_shouldAcceptControllerUpdate(gen: gen, newState: newState)) return;
      _applyControllerUpdate(newState);
    });
  }

  bool _shouldAcceptControllerUpdate({required int gen, required PlayerState newState}) {
    // 1) 丢弃旧控制器/旧设备的回调
    if (gen != _controllerGen) return false;
    // 2) build 未完成前 state 还没有值；避免在 AsyncLoading 阶段抢写
    if (!state.hasValue) return false;

    final activeDevice = state.value!.currentDevice;
    final activeType = activeDevice?.type;
    final activeDid = activeDevice?.did;

    // 3) 类型不匹配：直接丢弃
    if (_boundDeviceType != null && activeType != null && _boundDeviceType != activeType) return false;

    // 4) remote 模式必须 did 匹配（彻底解决 remote↔remote 串台）
    if (_boundDeviceType == DeviceType.remote) {
      if (_boundDid != null && activeDid != null && _boundDid != activeDid) return false;
      final newDid = newState.currentDevice?.did;
      if (_boundDid != null && newDid != null && _boundDid != newDid) return false;
    }

    return true;
  }

  void _applyControllerUpdate(PlayerState newState) {
    final activeDevice = state.value!.currentDevice;
    final activeType = activeDevice?.type;

    // 合并当前状态和更新状态，保留 activeDevice（避免 controller 内部读到的 currentDevice 漂移）
    state = AsyncData(
      newState.copyWith(
        currentDevice: activeDevice,
        playlist: newState.playlist.isNotEmpty ? newState.playlist : state.value!.playlist,
        currentIndex: newState.currentIndex >= 0 ? newState.currentIndex : state.value!.currentIndex,
        currentPlaylistName: newState.currentPlaylistName ?? state.value!.currentPlaylistName,
      ),
    );

    // 本地设备：防抖持久化，避免 position 高频更新导致卡顿/掉帧
    if (activeType == DeviceType.local) {
      _schedulePersistPlayerState(state.value!);
    }
  }

  /// 获取设备列表（使用统一的 Provider）
  Future<Map<String, Device>> _getDevices() {
    return ref.read(playerDevicesProvider.future);
  }

  /// 获取当前设备ID（用于监听变化）
  String? _getCurrentDeviceId() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(SharedPrefKeys.currentDeviceId);
  }

  /// 获取当前设备
  Future<Device> _getCurrentDevice() async {
    final deviceId = _getCurrentDeviceId();
    final devices = await _getDevices();

    // 选择目标设备
    if (deviceId != null && devices.containsKey(deviceId)) {
      // 如果有保存的设备ID，使用保存的设备
      return devices[deviceId]!;
    } else {
      // 获取远程设备（排除本地设备）
      final remoteDevices = devices.values.where((d) => d.type == DeviceType.remote).toList();
      if (remoteDevices.isNotEmpty) {
        // 如果是首次登录且有远程设备，默认选择第一个远程设备
        return remoteDevices.first;
      } else {
        // 否则使用本地设备
        if (devices.containsKey(BaseConstants.webDevice)) {
          return devices[BaseConstants.webDevice]!;
        }
        // 如果列表中没有本地设备，创建一个默认的本地设备对象
        return Device(did: BaseConstants.webDevice, type: DeviceType.local, name: '本机');
      }
    }
  }

  @override
  Future<PlayerState> build() async {
    _ensureDisposeHook();

    final currentDevice = await _getCurrentDevice();
    _logger.i("初始化 UnifiedPlayerController 当前设备: ${jsonEncode(currentDevice.toJson())}");

    // 先尝试恢复播放状态（在初始化控制器之前）
    final restoredState = await _restorePlayerState(currentDevice);

    // 初始化播放控制器
    await _initializePlayerController(currentDevice, initialState: restoredState);

    // 对于本地设备，优先从控制器获取最新状态（因为可能正在播放，或者在初始化过程中修正了状态如强制暂停）
    // 并与缓存状态合并
    if (currentDevice.type == DeviceType.local && _playerController is LocalPlayerControllerImpl) {
      final controllerState = await _playerController?.getState();
      if (controllerState != null) {
        // 如果控制器有当前歌曲，说明正在播放或已恢复，使用控制器状态为主
        // 注意：LocalPlayerController 初始化时已经合并了 restoredState 的信息
        if (controllerState.currentSong != null && controllerState.currentSong!.isNotEmpty) {
          final finalState = controllerState.copyWith(currentDevice: currentDevice);
          // 初始化跟踪变量
          _lastPersistedSong = finalState.currentSong;
          _lastPersistedIsPlaying = finalState.isPlaying;
          _lastPersistedLoopMode = finalState.loopMode;
          _lastPersistedShuffleMode = finalState.shuffleMode;
          _lastPersistedPositionSeconds = finalState.position.inSeconds;
          return finalState;
        }
      }
    }

    // 如果有恢复的状态，使用它；否则从控制器获取当前状态
    if (restoredState != null) {
      // 初始化跟踪变量，避免恢复后的第一次状态更新被误判为变化
      _lastPersistedSong = restoredState.currentSong;
      _lastPersistedIsPlaying = restoredState.isPlaying;
      _lastPersistedLoopMode = restoredState.loopMode;
      _lastPersistedShuffleMode = restoredState.shuffleMode;
      _lastPersistedPositionSeconds = restoredState.position.inSeconds;
      return restoredState;
    }

    // 从控制器获取当前状态
    final currentState = await _playerController?.getState();
    final finalState =
        currentState?.copyWith(currentDevice: currentDevice) ?? PlayerState(currentDevice: currentDevice);
    // 初始化跟踪变量
    _lastPersistedSong = finalState.currentSong;
    _lastPersistedIsPlaying = finalState.isPlaying;
    _lastPersistedLoopMode = finalState.loopMode;
    _lastPersistedShuffleMode = finalState.shuffleMode;
    _lastPersistedPositionSeconds = finalState.position.inSeconds;
    return finalState;
  }

  Future<void> _initializePlayerController(Device currentDevice, {PlayerState? initialState}) async {
    final isLocalMode = currentDevice.type == DeviceType.local;
    final isRemoteMode = currentDevice.type == DeviceType.remote;

    // 判断是否需要重建控制器（类型不同时必须重建）
    final needsRecreate =
        _playerController == null ||
        (isLocalMode && _playerController is! LocalPlayerControllerImpl) ||
        (isRemoteMode && _playerController is! RemotePlayerControllerImpl);

    if (needsRecreate) {
      // 记录旧控制器
      final oldController = _playerController;
      _playerController = null;

      // 销毁旧控制器（确保在创建新控制器前完成销毁）
      // 注意：不在这里停止播放器，因为 AudioPlayer 是共享单例
      // 播放器的停止和模式切换由 setRemoteMode 统一管理
      if (oldController != null) {
        await oldController.dispose();
      }

      // 创建新控制器
      final handler = await ref.read(audioHandlerProvider.future);

      if (isLocalMode) {
        final localController = LocalPlayerControllerImpl(handler, ref, initialState: initialState);
        // 等待本地控制器初始化完成（确保 setRemoteMode(false) 执行完毕）
        await localController.initialize();
        _playerController = localController;
      } else {
        final remoteController = RemotePlayerControllerImpl(ref, handler);
        // 等待远程控制器初始化完成（确保 setRemoteMode 执行完毕）
        // setRemoteMode(true) 内部会停止播放器并等待 MediaCodec 释放
        await remoteController.initialize();
        _playerController = remoteController;
      }
    }

    // 绑定回调
    await _bindControllerCallback(currentDevice);

    // 远程模式：更新轮询目标
    if (isRemoteMode && _playerController is RemotePlayerControllerImpl) {
      final remoteController = _playerController as RemotePlayerControllerImpl;
      if (currentDevice.did.isNotEmpty) {
        remoteController.startPolling(currentDevice.did);
      } else {
        remoteController.stopPolling();
      }
    }
  }

  /// 获取指定设备的真实播放状态
  Future<PlayerState?> _getDeviceRealState(Device? currentDevice) async {
    _logger.i("切换设备时获取设备真实状态: ${currentDevice?.toJson()}");
    try {
      final isLocalMode = currentDevice?.type == DeviceType.local;
      final did = currentDevice?.did;
      // 本地模式，远程控制器状态下想要查询本地设备状态，则从缓存获取状态
      if (isLocalMode && _playerController is RemotePlayerControllerImpl) {
        // 从 Hive 缓存获取状态
        final cacheManager = ref.read(cacheManagerProvider);
        final deviceKey = _getDeviceKey(currentDevice);

        final stateCache = cacheManager.getPlayerState(deviceKey);

        _logger.i(
          "远程切换本地,播放状态缓存从本地获取: song=${stateCache?.currentSong}, playlist=${stateCache?.playlist.length ?? 0}, index=${stateCache?.currentIndex ?? -1}",
        );

        // 如果缓存中有歌曲信息，使用缓存状态
        if (stateCache != null && stateCache.currentSong != null && stateCache.currentSong!.isNotEmpty) {
          final loopMode = LoopMode.values[stateCache.loopModeIndex];

          return PlayerState(
            currentSong: stateCache.currentSong,
            playlist: stateCache.playlist,
            currentIndex: stateCache.currentIndex >= 0 ? stateCache.currentIndex : 0,
            position: Duration(seconds: stateCache.positionSeconds),
            duration: Duration(seconds: stateCache.durationSeconds),
            isPlaying: stateCache.isPlaying,
            loopMode: loopMode,
            shuffleMode: stateCache.shuffleMode,
            currentPlaylistName: stateCache.currentPlaylistName,
            currentDevice: currentDevice,
          );
        }
        // 如果缓存中没有状态（首次使用），返回一个空的本地设备状态
        // 这确保设备切换时状态能正确更新
        _logger.i("缓存中没有状态，返回空的本地设备状态");
        return PlayerState(currentDevice: currentDevice);
      }
      // 本地模式且控制器已经是本地控制器，尝试从控制器获取状态
      else if (isLocalMode && _playerController is LocalPlayerControllerImpl) {
        try {
          final localState = await _playerController?.getState();
          if (localState != null) {
            return localState.copyWith(currentDevice: currentDevice);
          }
        } catch (e) {
          _logger.w('从本地控制器获取状态失败: $e');
        }
        // 如果无法从控制器获取状态，返回一个空的本地设备状态
        _logger.i("无法从本地控制器获取状态，返回空的本地设备状态");
        return PlayerState(currentDevice: currentDevice);
      }
      // 远程模式:设备did不是web设备,则从API获取真实状态
      else if (did != null && did.isNotEmpty && did != BaseConstants.webDevice) {
        // 远程模式：从API获取真实状态
        final apiClient = ref.read(apiClientProvider);
        final remoteStatus = await apiClient.getPlayingMusic(did, null);
        final playlistName = remoteStatus.curPlaylist.trim();
        final currentSong = remoteStatus.curMusic;

        // 从当前状态获取完整信息
        final currentState = state.value ?? PlayerState(currentDevice: currentDevice);

        // 比对歌单，一致则保留队列，否则尝试从本地缓存加载
        List<String> playlist = currentState.playlist;
        if (playlistName.isNotEmpty && currentState.currentPlaylistName != playlistName) {
          try {
            final songsResp = await ref.read(cachedPlaylistMusicsProvider(playlistName).future);
            playlist = songsResp.musics;
          } catch (e) {
            // 保持原队列
            _logger.e("获取歌单 $playlistName 失败，保持原队列: $e");
          }
        }

        int resolvedIndex = currentState.currentIndex;
        if (playlist.isNotEmpty && currentSong.isNotEmpty) {
          final found = playlist.indexOf(currentSong);
          if (found >= 0) {
            resolvedIndex = found;
          } else if (resolvedIndex < 0) {
            resolvedIndex = 0;
          }
        }

        return currentState.copyWith(
          isPlaying: remoteStatus.isPlaying,
          currentSong: currentSong,
          currentPlaylistName: playlistName.isNotEmpty ? playlistName : currentState.currentPlaylistName,
          playlist: playlist,
          currentIndex: resolvedIndex,
          position: Duration(seconds: remoteStatus.offset.toInt()),
          duration: Duration(seconds: remoteStatus.duration.toInt()),
          currentDevice: currentDevice,
        );
      }
    } catch (e) {
      _logger.e('获取设备真实状态失败: $e');
    }
    _logger.i("同设备切换,获取设备真实状态,返回当前默认状态: ${state.value?.toJsonIgnorePlaylist()}");
    return null;
  }

  /// 暂停当前设备
  Future<void> _pauseCurrentDevice(Device? currentDevice) async {
    if (currentDevice == null) return;

    try {
      if (currentDevice.type == DeviceType.local) {
        // 本地模式：通过控制器暂停
        // 注意：在设备切换时，_playerController 还是旧的本地控制器
        if (_playerController is LocalPlayerControllerImpl) {
          final localState = await _playerController?.getState();
          if (localState?.isPlaying == true) {
            _logger.i('暂停本地播放器');
            await _playerController?.playPause();
          }
        }
      } else {
        // 远程模式：通过API暂停
        final did = currentDevice.did;
        if (did.isNotEmpty) {
          final apiClient = ref.read(apiClientProvider);
          final remoteStatus = await apiClient.getPlayingMusic(did, null);
          if (remoteStatus.isPlaying) {
            _logger.i('暂停远程设备: $did');
            await apiClient.sendCmd(DidCmd(did: did, cmd: PlayerCommands.pause));
          }
        }
      }
    } catch (e) {
      _logger.e('暂停当前设备失败: $e');
    }
  }

  /// 处理设备切换（简化优化版）
  Future<void> _handleDeviceSwitch(Device? prevDevice, Device newDevice) async {
    final switchGen = ++_switchGen;

    // 如果设备相同，不需要切换
    if (prevDevice?.did == newDevice.did) {
      // 即使设备ID相同，如果设备对象更新了（比如设备信息更新），也要更新状态
      if (state.hasValue) {
        state = AsyncData(state.value!.copyWith(currentDevice: newDevice));
      }
      return;
    }

    final settings = ref.read(settingsProvider);
    final pauseCurrentDevice = settings.pauseCurrentDeviceOnSwitch;
    final syncPlayback = settings.syncPlaybackOnSwitch;
    final newIsLocal = newDevice.type == DeviceType.local;

    // 1. 获取当前设备的真实状态并保存
    PlayerState? previousState;
    if (prevDevice != null) {
      previousState = state.value;
      if (switchGen != _switchGen) return;
      // 仅保存本地设备的状态
      if (previousState != null && prevDevice.type == DeviceType.local) {
        final deviceKey = _getDeviceKey(prevDevice);
        unawaited(_savePlayerStateForDevice(previousState, deviceKey));
      }
    }

    // 2. 决定是否暂停当前设备（跨类型切换强制暂停，同类型根据配置）
    if (prevDevice != null) {
      final prevIsLocal = prevDevice.type == DeviceType.local;
      final typeChanged = prevIsLocal != newIsLocal;
      final shouldPause = typeChanged || (pauseCurrentDevice && previousState?.isPlaying == true);

      if (shouldPause) {
        await _pauseCurrentDevice(prevDevice);
        if (switchGen != _switchGen) return;
      }
    }

    // 3. 恢复新设备状态（仅本地设备）
    final initialState = newIsLocal ? await _restorePlayerState(newDevice) : null;
    if (switchGen != _switchGen) return;

    // 4. 重新初始化控制器（确保控制器与新设备匹配）
    // 这对于远程设备之间的切换尤其重要，需要更新轮询目标
    await _initializePlayerController(newDevice, initialState: initialState);
    if (switchGen != _switchGen) return;

    // 5. 同步最终状态
    try {
      final realState = await _getDeviceRealState(newDevice);
      if (switchGen == _switchGen) {
        final finalState =
            realState ??
            initialState ??
            // 如果两者都是 null（首次使用），创建一个新的空状态，确保设备信息正确更新
            // 这解决了首次从远程切换到本地时，状态不更新的问题
            (() {
              _logger.i('首次切换到设备 ${newDevice.did}，创建新的空状态');
              return PlayerState(currentDevice: newDevice);
            })();
        state = AsyncData(finalState);
        // 初始化跟踪变量，避免恢复后的第一次状态更新被误判为变化
        _lastPersistedSong = finalState.currentSong;
        _lastPersistedIsPlaying = finalState.isPlaying;
        _lastPersistedLoopMode = finalState.loopMode;
        _lastPersistedShuffleMode = finalState.shuffleMode;
        _lastPersistedPositionSeconds = finalState.position.inSeconds;
      }
    } catch (e) {
      _logger.e('同步状态失败: $e');
      // 即使出错，也要确保设备信息更新
      if (switchGen == _switchGen) {
        final emptyState = PlayerState(currentDevice: newDevice);
        state = AsyncData(emptyState);
        // 初始化跟踪变量
        _lastPersistedSong = emptyState.currentSong;
        _lastPersistedIsPlaying = emptyState.isPlaying;
        _lastPersistedLoopMode = emptyState.loopMode;
        _lastPersistedShuffleMode = emptyState.shuffleMode;
        _lastPersistedPositionSeconds = emptyState.position.inSeconds;
      }
    }

    // 5. 同步播放内容（如果配置了同步）
    if (syncPlayback && previousState != null && previousState.isPlaying) {
      final song = previousState.currentSong;
      final playlist = previousState.currentPlaylistName;
      if (song != null && song.isNotEmpty) {
        try {
          if (newIsLocal) {
            await _playerController?.playSong(song, playlistName: playlist);
          } else {
            // 远程：直接发送播放命令
            final apiClient = ref.read(apiClientProvider);
            if (playlist != null && playlist.isNotEmpty) {
              await apiClient.playMusicList(DidPlayMusicList(did: newDevice.did, listname: playlist, musicname: song));
            } else {
              await apiClient.playMusic(DidPlayMusic(did: newDevice.did, musicname: song, listname: playlist ?? ""));
            }
          }
        } catch (e) {
          _logger.e('同步播放失败: $e');
        }
        if (switchGen != _switchGen) return;
      }
    }
  }

  /// 保存指定设备的播放状态（内部方法，用于设备切换时保存）
  Future<void> _savePlayerStateForDevice(PlayerState state, String deviceKey) async {
    // 仅本地设备需要持久化
    if (deviceKey != BaseConstants.webDevice) return;
    try {
      // 确保 Hive 已初始化
      await ref.read(initCacheProvider.future);

      final cacheManager = ref.read(cacheManagerProvider);
      final stateCache = PlayerStateCache(
        currentSong: state.currentSong,
        playlist: state.playlist,
        currentIndex: state.currentIndex,
        positionSeconds: state.position.inSeconds,
        durationSeconds: state.duration.inSeconds,
        isPlaying: state.isPlaying,
        loopModeIndex: state.loopMode.index,
        shuffleMode: state.shuffleMode,
        currentPlaylistName: state.currentPlaylistName,
        lastUpdated: DateTime.now(),
      );
      await cacheManager.savePlayerState(deviceKey, stateCache);
      _logger.d('设备切换时保存播放状态到 Hive: deviceKey=$deviceKey, song=${state.currentSong}');
    } catch (e, st) {
      _logger.e('保存播放状态失败: $e', error: e, stackTrace: st);
    }
  }

  /// 统一播放歌曲方法
  Future<void> playSong(String songName, {String? playlistName}) async {
    // 防抖处理
    _playSongDebounceTimer?.cancel();
    _pendingSongName = songName;
    _pendingPlaylistName = playlistName;

    _playSongDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _playerController?.playSong(_pendingSongName!, playlistName: _pendingPlaylistName);
      _pendingSongName = null;
      _pendingPlaylistName = null;
    });
  }

  /// 播放整个歌单
  Future<void> playPlaylistByName(String playlistName) async {
    await _playerController?.playPlaylistByName(playlistName);
  }

  /// 在当前播放队列中切换歌曲
  Future<void> playFromQueueIndex(int index) async {
    await _playerController?.playFromQueueIndex(index);
  }

  /// 播放/暂停
  Future<void> playPause() async {
    await _playerController?.playPause();
  }

  /// 下一首
  Future<void> skipNext() async {
    await _playerController?.skipNext();
  }

  /// 上一首
  Future<void> skipPrevious() async {
    await _playerController?.skipPrevious();
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _playerController?.seek(position);
  }

  /// 切换循环模式
  Future<void> toggleLoopMode() async {
    await _playerController?.toggleLoopMode();
  }

  /// 切换随机模式
  Future<void> toggleShuffleMode() async {
    await _playerController?.toggleShuffleMode();
  }

  /// 切换播放模式（顺序、单曲、全部、随机）
  Future<void> togglePlayMode() async {
    await _playerController?.togglePlayMode();
  }

  /// 设置音量
  Future<void> setVolume(int volume) async {
    await _playerController?.setVolume(volume);
  }

  /// 定时关机
  Future<void> sendShutdownCommand(int minutes) async {
    await _playerController?.sendShutdownCommand(minutes);
  }

  /// 获取设备标识（用于缓存key）
  String _getDeviceKey(Device? currentDevice) {
    if (currentDevice?.type == DeviceType.local) {
      return BaseConstants.webDevice;
    }
    return currentDevice?.did ?? 'unknown';
  }

  /// 保存播放状态到本地缓存（按设备隔离）
  Future<void> savePlayerState() async {
    // 安全检查：确保 state 可用
    if (!state.hasValue) return;
    final curState = state.value;
    if (curState == null) return;

    // 仅本地设备需要持久化
    if (curState.currentDevice?.type != DeviceType.local) return;
    try {
      // 确保 Hive 已初始化
      await ref.read(initCacheProvider.future);

      final cacheManager = ref.read(cacheManagerProvider);
      final deviceKey = _getDeviceKey(curState.currentDevice);

      final stateCache = PlayerStateCache(
        currentSong: curState.currentSong,
        playlist: curState.playlist,
        currentIndex: curState.currentIndex,
        positionSeconds: curState.position.inSeconds,
        durationSeconds: curState.duration.inSeconds,
        isPlaying: curState.isPlaying,
        loopModeIndex: curState.loopMode.index,
        shuffleMode: curState.shuffleMode,
        currentPlaylistName: curState.currentPlaylistName,
        lastUpdated: DateTime.now(),
      );
      await cacheManager.savePlayerState(deviceKey, stateCache);
      _logger.d(
        '保存播放状态到 Hive: deviceKey=$deviceKey, song=${curState.currentSong}, playlist=${curState.playlist.length}',
      );
    } catch (e, st) {
      _logger.e('保存播放状态失败: $e', error: e, stackTrace: st);
    }
  }

  void _schedulePersistPlayerState(PlayerState s) {
    // 仅本地设备需要持久化
    if (s.currentDevice?.type != DeviceType.local) return;

    final posSec = s.position.inSeconds;
    final songChanged = _lastPersistedSong != s.currentSong;
    final playingChanged = _lastPersistedIsPlaying != s.isPlaying;
    final loopModeChanged = _lastPersistedLoopMode != s.loopMode;
    final shuffleModeChanged = _lastPersistedShuffleMode != s.shuffleMode;
    final positionChanged =
        _lastPersistedPositionSeconds < 0 || ((posSec - _lastPersistedPositionSeconds).abs() >= 1); // 至少1秒变化才触发，避免过于频繁

    // 没有任何变化，直接返回
    if (!songChanged && !playingChanged && !loopModeChanged && !shuffleModeChanged && !positionChanged) {
      return;
    }

    _saveStateDebounceTimer?.cancel();

    // 如果歌曲变化、播放状态变化或播放模式变化，立即保存（不等待防抖），确保切换歌曲、暂停/播放或切换播放模式时状态能及时保存
    if (songChanged || playingChanged || loopModeChanged || shuffleModeChanged) {
      unawaited(
        savePlayerState().then((_) {
          // 以落盘时的最新 state 为准，确保 _lastPersisted* 与实际保存的状态一致
          final latest = state.value;
          if (latest != null) {
            _lastPersistedPositionSeconds = latest.position.inSeconds;
            _lastPersistedIsPlaying = latest.isPlaying;
            _lastPersistedSong = latest.currentSong;
            _lastPersistedLoopMode = latest.loopMode;
            _lastPersistedShuffleMode = latest.shuffleMode;
          }
        }),
      );
    } else if (positionChanged) {
      // 只有位置变化时使用防抖（统一500ms，减少频繁写入）
      _saveStateDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        // 以落盘时的最新 state 为准，确保 _lastPersisted* 与实际保存的状态一致
        unawaited(
          savePlayerState().then((_) {
            final latest = state.value;
            if (latest != null) {
              _lastPersistedPositionSeconds = latest.position.inSeconds;
              _lastPersistedIsPlaying = latest.isPlaying;
              _lastPersistedSong = latest.currentSong;
              _lastPersistedLoopMode = latest.loopMode;
              _lastPersistedShuffleMode = latest.shuffleMode;
            }
          }),
        );
      });
    }
  }

  /// 从本地缓存恢复播放状态（按设备隔离）
  Future<PlayerState?> _restorePlayerState(Device? currentDevice) async {
    // 远程设备不做本地恢复，直接走接口
    if (currentDevice?.type == DeviceType.remote) return null;
    try {
      // 确保 Hive 已初始化
      await ref.read(initCacheProvider.future);

      final cacheManager = ref.read(cacheManagerProvider);
      final deviceKey = _getDeviceKey(currentDevice);

      // 从 Hive 读取
      final stateCache = cacheManager.getPlayerState(deviceKey);

      if (stateCache != null && stateCache.currentSong != null && stateCache.currentSong!.isNotEmpty) {
        _logger.i(
          '从 Hive 恢复播放状态: song=${stateCache.currentSong}, playlist=${stateCache.playlist.length}, index=${stateCache.currentIndex}',
        );
        final loopMode = LoopMode.values[stateCache.loopModeIndex];

        return PlayerState(
          currentSong: stateCache.currentSong,
          playlist: stateCache.playlist,
          currentIndex: stateCache.currentIndex >= 0 ? stateCache.currentIndex : 0,
          position: Duration(seconds: stateCache.positionSeconds),
          duration: Duration(seconds: stateCache.durationSeconds),
          isPlaying: stateCache.isPlaying,
          loopMode: loopMode,
          shuffleMode: stateCache.shuffleMode,
          currentPlaylistName: stateCache.currentPlaylistName,
          currentDevice: currentDevice,
        );
      } else {
        _logger.d('Hive 中没有找到播放状态缓存: deviceKey=$deviceKey');
      }
    } catch (e, st) {
      _logger.e('恢复播放状态失败: $e', error: e, stackTrace: st);
    }
    return null;
  }

  /// 切换设备
  Future<void> setDevice(Device device) async {
    // 如果设备相同，不需要切换
    final currentDevice = state.value?.currentDevice;
    if (currentDevice?.did == device.did) {
      // 即使设备ID相同，如果设备对象更新了（比如设备信息更新），也要更新状态
      if (state.hasValue) {
        state = AsyncData(state.value!.copyWith(currentDevice: device));
      }
      return;
    }

    // 更新本地缓存当前设备ID
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(SharedPrefKeys.currentDeviceId, device.did);

    // 获取之前的设备
    final prevDevice = currentDevice;

    // 处理设备切换（统一逻辑，内部会更新状态）
    await _handleDeviceSwitch(prevDevice, device);
  }

  /// 发送命令（远程模式）
  Future<void> sendCmd(String cmd) async {
    final currentDevice = state.value?.currentDevice;
    if (currentDevice == null || currentDevice.type != DeviceType.remote) return;

    final did = currentDevice.did;
    if (did.isEmpty) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.sendCmd(DidCmd(did: did, cmd: cmd));
    } catch (e) {
      _logger.e('发送命令失败: $e');
    }
  }

  /// 播放TTS（远程模式）
  Future<void> playTts(String text) async {
    final currentDevice = state.value?.currentDevice;
    if (currentDevice == null || currentDevice.type != DeviceType.remote) return;

    final did = currentDevice.did;
    if (did.isEmpty) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.playTts(did, text);
    } catch (e) {
      _logger.e('播放TTS失败: $e');
    }
  }

  /// 播放音乐（兼容旧接口，内部调用 playSong）
  Future<void> playMusic(String musicName, {String? playlistName}) async {
    await playSong(musicName, playlistName: playlistName);
  }

  /// 刷新当前播放队列关联的歌单内容
  Future<void> refreshCurrentPlaylist() async {
    if (!state.hasValue) return;
    final cur = state.value!;
    final playlistName = cur.currentPlaylistName;

    if (playlistName == null || playlistName.isEmpty) return;

    try {
      // 从缓存读取歌单内容
      final songsResp = await ref.read(cachedPlaylistMusicsProvider(playlistName).future);
      final newSongs = songsResp.musics;

      // 重新计算索引
      final currentSong = cur.currentSong;
      int resolvedIndex = -1;
      if (currentSong != null && newSongs.isNotEmpty) {
        resolvedIndex = newSongs.indexOf(currentSong);
      }

      // 更新状态
      if (state.hasValue) {
        state = AsyncData(cur.copyWith(playlist: newSongs, currentIndex: resolvedIndex >= 0 ? resolvedIndex : 0));
      }
    } catch (e) {
      _logger.e('刷新歌单 $playlistName 失败: $e');
    }
  }
}
