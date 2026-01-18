import 'dart:async';

import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/cmd_commands.dart';
import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/i_player_controller.dart';
import 'package:mi_music/data/providers/player/player_state.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';
import 'package:mi_music/data/providers/system_provider.dart';
import 'package:mi_music/data/services/audio_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

final _logger = Logger();

/// 远程播放控制器实现
class RemotePlayerControllerImpl implements IPlayerController {
  final Ref _ref;
  final MyAudioHandler? _handler;
  Timer? _pollTimer;
  StreamSubscription? _statusSub;
  void Function(PlayerState)? _stateUpdateCallback;
  PlayerState? _currentState;
  String? _currentDid;
  bool _disposed = false; // 标记控制器是否已被销毁
  int _pollGen = 0; // 轮询代际，用于丢弃过期的异步结果（防止设备切换串台）
  static const _localDeviceId = 'web_device';

  RemotePlayerControllerImpl(this._ref, this._handler);

  /// 初始化控制器（必须在创建后调用）
  Future<void> initialize() async {
    await _initHandler();
  }

  Future<void> _initHandler() async {
    final handler = _handler;
    if (handler == null) return;

    // 启用托管模式（异步，确保播放器完全停止）
    await handler.setRemoteMode(true);

    // 注册回调：将通知栏事件转发给控制器方法
    handler.setRemoteCallbacks(
      onPlay: () async => playPause(),
      onPause: () async => playPause(),
      onNext: () async => skipNext(),
      onPrevious: () async => skipPrevious(),
      // stop 视情况转发，这里暂不处理或也调 pause
    );
  }

  /// 将 playType 转换为 LoopMode 和 shuffleMode
  /// playType: 1=全部循环, 2=随机播放, 3=单曲循环, 4=顺序播放
  static ({LoopMode loopMode, bool shuffleMode}) _playTypeToMode(int? playType) {
    switch (playType) {
      case 1: // 全部循环
        return (loopMode: LoopMode.all, shuffleMode: false);
      case 2: // 随机播放
        return (loopMode: LoopMode.all, shuffleMode: true);
      case 3: // 单曲循环
        return (loopMode: LoopMode.one, shuffleMode: false);
      case 4: // 顺序播放
      default:
        return (loopMode: LoopMode.off, shuffleMode: false);
    }
  }

  /// 获取当前设备
  Device? _getCurrentDevice() {
    // 优先从状态中获取
    if (_currentState?.currentDevice != null) {
      return _currentState!.currentDevice;
    }

    // 从 SharedPreferences 和设备列表获取
    final prefs = _ref.read(sharedPreferencesProvider);
    final deviceId = prefs.getString(SharedPrefKeys.currentDeviceId);

    // 获取设备列表（使用统一的 Provider）
    // remote_player_controller 不负责初始化时机，因此如果 devices 还是 Future，这里可能会报错
    // 但 playerDevicesProvider 已经被改为 FutureProvider，ref.read(playerDevicesProvider) 会返回 AsyncValue 或者 Future
    // 这里需要根据 Provider 的类型做调整。
    // 如果 playerDevicesProvider 是 FutureProvider，ref.read 会返回 AsyncValue<Map<String, Device>>
    // 我们应该使用 ref.read(playerDevicesProvider.future) 并改为异步方法，或者使用 .valueOrNull

    // 由于 _getCurrentDevice 在同步流程中被调用（例如 fetchInitialStatus, startPolling等虽然是async，但内部有些逻辑是同步的），
    // 且 IPlayerController 接口方法大多是 Future，我们可以把 _getCurrentDevice 改为异步，或者尽量使用 ref.read 的同步读取方式（如果已加载）。

    // 鉴于 playerDevicesProvider 已经是 FutureProvider，ref.read(playerDevicesProvider) 返回的是 AsyncValue。
    final devicesAsync = _ref.read(playerDevicesProvider);
    final devices = devicesAsync.value ?? {};

    if (deviceId != null && devices.containsKey(deviceId)) {
      return devices[deviceId];
    } else {
      final remoteDevicesList = devices.values.where((d) => d.type == DeviceType.remote).toList();
      if (remoteDevicesList.isNotEmpty) {
        return remoteDevicesList.first;
      } else {
        return devices[_localDeviceId];
      }
    }
  }

  Device? _getDeviceByDid(String did) {
    final devicesAsync = _ref.read(playerDevicesProvider);
    final devices = devicesAsync.value ?? {};
    return devices[did];
  }

  void startPolling(String? did) {
    if (did == null) return;

    // 先停止旧的轮询（如果存在）
    stopPolling();

    _currentDid = did;
    _pollGen++;
    final gen = _pollGen;

    // 立即查询一次
    _fetchRemoteStatus(did, gen: gen);

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchRemoteStatus(did, gen: gen);
    });
  }

  void stopPolling() {
    // 让所有进行中的请求过期（Timer cancel 不能取消已发出的异步请求）
    _pollGen++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _statusSub?.cancel();
    _statusSub = null;
    _currentDid = null;
  }

  Future<PlayerState?> _fetchRemoteStatus(String did, {required int gen}) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final resp = await apiClient.getPlayingMusic(did);

      // 检查是否已被销毁（异步操作期间可能被销毁）
      if (_disposed) {
        return _currentState;
      }
      // 设备切换/停止轮询后，丢弃过期结果，避免串台
      if (gen != _pollGen || _currentDid != did) {
        return _currentState;
      }

      // 处理异常超长时长（>10h 视为异常）
      final durationSeconds = resp.duration.toInt();
      final duration = durationSeconds > 36000 ? Duration.zero : Duration(seconds: durationSeconds);

      // 按 did 解析对应设备，避免切换后读取到新的“当前设备”导致错配
      final currentDevice = _getDeviceByDid(did) ?? _currentState?.currentDevice ?? _getCurrentDevice();
      final playlistName = resp.curPlaylist.trim();
      final currentSong = resp.curMusic;

      // 以当前状态为基础（若为空则创建默认状态以便后续合并）
      final baseState = _currentState ?? PlayerState(currentDevice: currentDevice);

      // 是否与现有歌单一致，避免无谓替换队列
      final samePlaylist = playlistName.isNotEmpty && baseState.currentPlaylistName == playlistName;

      List<String> playlist = baseState.playlist;
      if (!samePlaylist && playlistName.isNotEmpty) {
        try {
          // 尝试从缓存获取
          var songsResp = await _ref.read(cachedPlaylistMusicsProvider(playlistName).future);

          // 如果缓存为空，尝试从 API 获取（兜底逻辑）
          if (songsResp.musics.isEmpty) {
            _logger.w("没有从缓存中找到对应歌单 $playlistName, 尝试从 API 获取");
            songsResp = await _ref.read(playlistMusicsProvider(playlistName).future);
            _logger.w("从 API 获取歌单 $playlistName 结果: ${songsResp.musics.length}");
          }

          playlist = songsResp.musics;
        } catch (e) {
          // 获取失败则清空队列
          playlist = const [];
          _logger.e("获取歌单 $playlistName 失败: $e");
        }
      }

      // 解析当前索引
      int resolvedIndex = baseState.currentIndex;
      if (playlist.isNotEmpty && currentSong.isNotEmpty) {
        final found = playlist.indexOf(currentSong);
        if (found >= 0) {
          resolvedIndex = found;
        } else if (resolvedIndex < 0) {
          resolvedIndex = 0;
        }
      } else if (playlist.isNotEmpty && resolvedIndex < 0) {
        resolvedIndex = 0;
      }

      // 从设备信息中获取播放模式（playType）
      final playMode = currentDevice?.playType != null
          ? _playTypeToMode(currentDevice!.playType)
          : (loopMode: baseState.loopMode, shuffleMode: baseState.shuffleMode);

      final updatedState = baseState.copyWith(
        isPlaying: resp.isPlaying,
        currentSong: currentSong,
        currentPlaylistName: playlistName.isNotEmpty ? playlistName : baseState.currentPlaylistName,
        playlist: playlist,
        currentIndex: resolvedIndex,
        position: Duration(seconds: resp.offset.toInt()),
        duration: duration,
        currentDevice: currentDevice,
        loopMode: playMode.loopMode,
        shuffleMode: playMode.shuffleMode,
      );

      // 再次检查是否已被销毁（可能在加载歌单期间被销毁）
      if (_disposed) {
        return _currentState;
      }
      // 二次校验：加载歌单期间可能发生设备切换
      if (gen != _pollGen || _currentDid != did) {
        return _currentState;
      }

      _currentState = updatedState;

      if (!_disposed) {
        // 同步到 UI 回调
        _stateUpdateCallback?.call(updatedState);
        // 从缓存获取封面URL并同步到通知栏
        Uri? artUri;
        if (updatedState.currentSong != null && updatedState.currentSong!.isNotEmpty) {
          try {
            final cacheManager = _ref.read(cacheManagerProvider);
            final songInfo = cacheManager.getSongInfo(updatedState.currentSong!);
            final pictureUrl = songInfo?.pictureUrl;
            if (pictureUrl != null && pictureUrl.isNotEmpty) {
              artUri = Uri.parse(pictureUrl);
            }
          } catch (e) {
            _logger.w('获取歌曲封面失败: $e');
          }
        }
        _handler?.updateStateFromExternal(updatedState, artUri: artUri);
      }
      return updatedState;
    } catch (e) {
      _logger.e("获取远程播放状态失败 (did: $did): $e");
      return _currentState;
    }
  }

  /// 主动拉取一次远程状态并更新
  Future<PlayerState?> fetchInitialStatus() async {
    final did = _currentDid ?? _getCurrentDevice()?.did;
    if (did == null) return _currentState;
    final gen = _pollGen;
    return _fetchRemoteStatus(did, gen: gen);
  }

  @override
  Future<PlayerState> getState() async {
    if (_currentState != null) {
      return _currentState!;
    }
    // 首次获取状态，尝试从API获取
    if (_currentDid != null) {
      final gen = _pollGen;
      await _fetchRemoteStatus(_currentDid!, gen: gen);
    }
    return _currentState ?? const PlayerState();
  }

  @override
  Future<void> setStateUpdateCallback(void Function(PlayerState) callback) async {
    _stateUpdateCallback = callback;
  }

  @override
  Future<void> dispose() async {
    // 标记为已销毁，防止异步操作继续更新状态
    _disposed = true;
    stopPolling();
    // 清空回调，避免已销毁的控制器继续更新状态
    _stateUpdateCallback = null;

    // 清空 Handler 的远程回调，但不停止 Service (防止通知栏消失)
    _handler?.setRemoteCallbacks(onPlay: null, onPause: null, onNext: null, onPrevious: null);
  }

  @override
  Future<void> playSong(String songName, {String? playlistName}) async {
    final currentDevice = _getCurrentDevice();
    final did = _currentDid ?? currentDevice?.did;
    if (did == null) return;

    // 更新状态
    _updateState(
      (_currentState ?? PlayerState(currentDevice: currentDevice)).copyWith(
        currentSong: songName,
        currentPlaylistName: playlistName,
        playlist: playlistName != null ? [] : [songName], // 如果有歌单，稍后加载
        currentIndex: 0,
        isPlaying: true, // 预期开始播放，先行更新UI
        currentDevice: currentDevice,
      ),
    );

    final apiClient = _ref.read(apiClientProvider);

    if (playlistName != null && playlistName.isNotEmpty) {
      // 如果有歌单，先加载歌单列表
      try {
        final songsResp = await _ref.read(cachedPlaylistMusicsProvider(playlistName).future);
        final songs = songsResp.musics;
        final index = songs.indexOf(songName);
        _updateState(
          (_currentState ?? PlayerState(currentDevice: currentDevice)).copyWith(
            playlist: songs,
            currentIndex: index >= 0 ? index : 0,
          ),
        );
      } catch (e) {
        _logger.e("加载歌单失败 (playlistName: $playlistName): $e");
      }

      await apiClient.playMusicList(DidPlayMusicList(did: did, listname: playlistName, musicname: songName));
    } else {
      await apiClient.playMusic(DidPlayMusic(did: did, musicname: songName, listname: playlistName ?? ""));
    }

    // 立即刷新状态
    final gen = _pollGen;
    await _fetchRemoteStatus(did, gen: gen);
  }

  @override
  Future<void> playPlaylistByName(String playlistName) async {
    final currentDevice = _getCurrentDevice();
    final did = _currentDid ?? currentDevice?.did;
    if (did == null) return;

    // 加载歌单列表
    String? musicName;
    try {
      final songsResp = await _ref.read(cachedPlaylistMusicsProvider(playlistName).future);
      final songs = songsResp.musics;

      // 默认使用第一首
      if (songs.isNotEmpty) {
        musicName = songs[0];
      }

      // 如果当前远程正在播放该歌单，且当前歌曲有效，则保持当前歌曲
      final currentState = await getState();
      if (currentState.currentPlaylistName == playlistName &&
          currentState.currentSong != null &&
          currentState.currentSong!.isNotEmpty) {
        // 检查当前歌曲是否在列表中
        if (songs.contains(currentState.currentSong)) {
          musicName = currentState.currentSong;
        }
      }

      _updateState(
        (_currentState ?? PlayerState(currentDevice: currentDevice)).copyWith(
          currentPlaylistName: playlistName,
          playlist: songs,
          currentIndex: musicName != null ? songs.indexOf(musicName) : 0,
          currentSong: musicName,
          currentDevice: currentDevice,
        ),
      );
    } catch (e) {
      _logger.e("加载歌单失败 (playlistName: $playlistName): $e");
    }

    final apiClient = _ref.read(apiClientProvider);
    await apiClient.playMusicList(DidPlayMusicList(did: did, listname: playlistName, musicname: musicName));

    // 立即刷新状态
    final gen = _pollGen;
    await _fetchRemoteStatus(did, gen: gen);
  }

  @override
  Future<void> playFromQueueIndex(int index) async {
    if (_currentState == null) return;
    final playlist = _currentState!.playlist;
    if (playlist.isEmpty || index < 0 || index >= playlist.length) return;

    final songName = playlist[index];
    final playlistName = _currentState!.currentPlaylistName;

    // 更新状态
    _updateState(_currentState!.copyWith(currentIndex: index, currentSong: songName, position: Duration.zero));

    // 通过播放歌曲名称来实现索引切换
    await playSong(songName, playlistName: playlistName);
  }

  void _updateState(PlayerState newState) {
    _currentState = newState;
    _stateUpdateCallback?.call(newState);
    // 从缓存获取封面URL并同步到通知栏
    Uri? artUri;
    if (newState.currentSong != null && newState.currentSong!.isNotEmpty) {
      try {
        final cacheManager = _ref.read(cacheManagerProvider);
        final songInfo = cacheManager.getSongInfo(newState.currentSong!);
        final pictureUrl = songInfo?.pictureUrl;
        if (pictureUrl != null && pictureUrl.isNotEmpty) {
          artUri = Uri.parse(pictureUrl);
        }
      } catch (e) {
        _logger.w('获取歌曲封面失败: $e');
      }
    }
    _handler?.updateStateFromExternal(newState, artUri: artUri);
  }

  @override
  Future<void> playPause() async {
    final currentDevice = _getCurrentDevice();
    final did = _currentDid ?? currentDevice?.did;
    if (did == null) return;

    final apiClient = _ref.read(apiClientProvider);
    final currentState = await getState();

    // 如果当前正在播放，则发送暂停命令
    if (currentState.isPlaying) {
      await apiClient.sendCmd(DidCmd(did: did, cmd: PlayerCommands.pause));
    } else {
      // 如果当前是暂停状态，则重新调用播放接口（带上当前的歌单和歌曲信息）
      // 这样可以确保远程设备正确恢复当前上下文播放，而不仅仅是解除暂停（有时单纯的 Play 命令可能无效）
      final playlistName = currentState.currentPlaylistName ?? "";
      final currentSong = currentState.currentSong ?? "";

      if (playlistName.isNotEmpty && currentSong.isNotEmpty) {
        await apiClient.playMusicList(DidPlayMusicList(did: did, listname: playlistName, musicname: currentSong));
      } else if (currentSong.isNotEmpty) {
        // 只有歌曲没有歌单，按单曲播放处理
        await apiClient.playMusic(DidPlayMusic(did: did, musicname: currentSong, listname: ""));
      } else {
        // 如果啥信息都没，尝试发送简单的 Play 命令作为兜底
        await apiClient.sendCmd(DidCmd(did: did, cmd: PlayerCommands.play));
      }
    }

    // 立即刷新状态
    final gen = _pollGen;
    await _fetchRemoteStatus(did, gen: gen);
  }

  @override
  Future<void> skipNext() async {
    final currentDevice = _getCurrentDevice();
    final did = currentDevice?.did;
    if (did == null) return;

    final apiClient = _ref.read(apiClientProvider);
    await apiClient.sendCmd(DidCmd(did: did, cmd: PlayerCommands.next));
  }

  @override
  Future<void> skipPrevious() async {
    final currentDevice = _getCurrentDevice();
    final did = currentDevice?.did;
    if (did == null) return;

    final apiClient = _ref.read(apiClientProvider);
    await apiClient.sendCmd(DidCmd(did: did, cmd: PlayerCommands.previous));
  }

  @override
  Future<void> seek(Duration position) async {
    // 远程播放器通常不支持精确seek
  }

  @override
  Future<void> toggleLoopMode() async {
    // 通过发送命令切换循环模式
    await togglePlayMode();
  }

  @override
  Future<void> toggleShuffleMode() async {
    // 通过发送命令切换随机模式
    await togglePlayMode();
  }

  @override
  Future<void> togglePlayMode() async {
    final currentDevice = _getCurrentDevice();
    final did = _currentDid ?? currentDevice?.did;
    if (did == null) return;

    final apiClient = _ref.read(apiClientProvider);

    // 重新获取设备信息（从最新的设备列表中获取）
    final updatedDevice = _getCurrentDevice();
    final currentPlayType = updatedDevice?.playType;

    _logger.d('当前播放模式 playType: $currentPlayType, 设备: ${updatedDevice?.name}');

    // 根据设备信息中的 playType 判断下一个模式
    // playType: 1=全部循环, 2=随机播放, 3=单曲循环, 4=顺序播放
    // 切换路径：全部循环(1) -> 随机播放(2) -> 单曲循环(3) -> 顺序播放(4) -> 全部循环(1)
    String cmd;
    if (currentPlayType == null || currentPlayType == 4) {
      // 顺序播放(4) 或未知 -> 全部循环(1)
      cmd = PlayerCommands.allLoop;
    } else if (currentPlayType == 1) {
      // 全部循环(1) -> 随机播放(2)
      cmd = PlayerCommands.shuffle;
    } else if (currentPlayType == 2) {
      // 随机播放(2) -> 单曲循环(3)
      cmd = PlayerCommands.singleLoop;
    } else if (currentPlayType == 3) {
      // 单曲循环(3) -> 顺序播放(4)
      cmd = PlayerCommands.sequential;
    } else {
      // 未知值，默认切换到全部循环
      cmd = PlayerCommands.allLoop;
    }

    _logger.d('发送播放模式切换命令: $cmd');
    await apiClient.sendCmd(DidCmd(did: did, cmd: cmd));

    // 刷新状态以同步播放模式和其他信息
    final gen = _pollGen;
    await _fetchRemoteStatus(did, gen: gen);
  }

  @override
  Future<void> setVolume(int volume) async {
    final currentDevice = _getCurrentDevice();
    final did = currentDevice?.did;
    if (did == null) return;

    final apiClient = _ref.read(apiClientProvider);
    await apiClient.setVolume(DidVolume(did: did, volume: volume.clamp(0, 100)));
  }

  @override
  Future<void> sendShutdownCommand(int minutes) async {
    final currentDevice = _getCurrentDevice();
    final did = currentDevice?.did;
    if (did == null) return;

    final apiClient = _ref.read(apiClientProvider);
    final cmd = PlayerCommands.shutdownAfterMinutes(minutes);
    await apiClient.sendCmd(DidCmd(did: did, cmd: cmd));
  }
}
