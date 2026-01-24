import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:logger/logger.dart';
import 'package:mi_music/data/cache/music_cache.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/i_player_controller.dart';
import 'package:mi_music/data/providers/player/player_state.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';
import 'package:mi_music/data/services/audio_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

final _logger = Logger();

/// 创建缓存音频源（从原 _createCachedAudioSource 提取）
Future<AudioSource> createCachedAudioSource({
  required String url,
  required String songName,
  required MusicCacheManager cacheManager,
  required Dio dio,
}) async {
  try {
    // 1. 尝试使用 LockCachingAudioSource (官方推荐的边下边播方案)
    // 之前可能因为代理问题禁用，现在作为首选尝试
    final cacheDir = await getApplicationCacheDirectory();
    final songsDir = Directory('${cacheDir.path}/songs');
    if (!await songsDir.exists()) {
      await songsDir.create(recursive: true);
    }
    final fileName = '${url.hashCode}.mp3';
    final file = File('${songsDir.path}/$fileName');

    // 如果文件已完全存在，直接播放文件（省流且稳定）
    // 需要更严谨的判断文件是否完整，比如对比文件大小
    // 这里简单判断：如果有对应的 .complete 标记文件，或者通过 cacheManager 确认完整
    // 暂且保留简单的文件存在判断，后续可优化
    if (await file.exists()) {
      // 进一步检查文件大小是否合理（例如 > 100KB），避免播放空文件
      if (await file.length() > 1024 * 100) {
        // _logger.d('Using local file source: ${file.path}');
        return AudioSource.file(file.path);
      }
    }

    // _logger.d('Using LockCachingAudioSource: $url');
    // 从缓存获取封面URL
    Uri? artUri;
    try {
      final songInfo = cacheManager.getSongInfo(songName);
      final pictureUrl = songInfo?.pictureUrl;
      if (pictureUrl != null && pictureUrl.isNotEmpty) {
        artUri = Uri.parse(pictureUrl);
      }
    } catch (e) {
      _logger.w('获取歌曲封面失败: $e');
    }
    // 使用 LockCachingAudioSource 自动管理下载和缓存
    return LockCachingAudioSource(
      Uri.parse(url),
      cacheFile: file,
      tag: MediaItem(id: songName, title: songName, artUri: artUri), // 附带元数据（包含封面）
    );
  } catch (e) {
    _logger.e("LockCachingAudioSource 失败，降级为在线播放: $e");
    // 降级策略：仅在线播放
    return AudioSource.uri(Uri.parse(url));
  }
}

/// 本地播放控制器实现
class LocalPlayerControllerImpl implements IPlayerController {
  final MyAudioHandler? _handler;
  final Ref _ref;
  final List<StreamSubscription<dynamic>> _subs = [];
  void Function(PlayerState)? _stateUpdateCallback;
  PlayerState? _currentState;
  bool _disposed = false; // 标记控制器是否已被销毁

  LocalPlayerControllerImpl(this._handler, this._ref, {PlayerState? initialState}) {
    _currentState = initialState;
    _logger.i('LocalPlayerControllerImpl: initialState: ${initialState?.toJsonIgnorePlaylist()}');
    // 不再在构造函数中调用 _initializeHandler()，改为通过 initialize() 方法显式调用
    _setupStateListeners();
  }

  /// 初始化控制器（必须在创建后调用，确保 setRemoteMode 完成）
  Future<void> initialize() async {
    await _initializeHandler();
  }

  Future<void> _initializeHandler() async {
    final handler = _handler;
    if (handler == null || _disposed) return;

    // 确保回到本地模式
    await handler.setRemoteMode(false);
    // 清除可能残留的远程回调
    handler.setRemoteCallbacks();

    // 提前设置回调，确保 _broadcastState 能获取到正确的索引
    // 必须在恢复播放状态之前设置，避免恢复过程中的 _broadcastState 调用时回调为 null
    handler.setPlaylistGetter(
      getPlaylist: () => _currentState?.playlist ?? const [],
      getCurrentIndex: () => _currentState?.currentIndex ?? 0,
      onIndexChanged: (index) {
        // 索引变化时同步更新状态
        if (_currentState != null && index >= 0) {
          final playlist = _currentState!.playlist;
          if (index < playlist.length) {
            _updateState(_currentState!.copyWith(currentIndex: index, currentSong: playlist[index]));
          }
        }
      },
    );

    // 恢复播放状态（循环模式、随机模式、当前歌曲）
    if (_currentState != null) {
      if (_disposed) return;
      // 1. 恢复循环和随机模式
      // 注意：setRepeatMode 内部会把 LoopMode.all 转换为内部状态并把底层设为 off
      final repeatMode = _mapLoopMode(_currentState!.loopMode);
      final shuffleMode = _currentState!.shuffleMode ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;

      await handler.setRepeatMode(repeatMode);
      await handler.setShuffleMode(shuffleMode);

      // 2. 恢复当前歌曲（如果不加载，点击播放会无效）
      // 注意：如果恢复过程耗时较长，此时用户可能已经发起了新的播放请求（如 playPlaylistByName）
      // 因此在恢复完成后，需要检查 _currentState 是否已经被新的操作更新，避免用旧状态覆盖新状态
      if (_currentState!.currentSong != null && _currentState!.currentSong!.isNotEmpty) {
        // 记录开始恢复时的状态版本
        final stateAtStart = _currentState!;

        // 必须 await：否则 _isRestoring 可能长时间为 true，导致 UI 监听被抑制
        await _restoreCurrentSong(handler, stateAtStart);
      }
    }

    // 注入 URL 获取器，确保在未预加载列表时也能按索引播放
    handler.setAudioSourceFetcher((song) async {
      try {
        return await _fetchAudioSource(song);
      } catch (e) {
        _logger.e("获取音频源失败: $e");
        return null;
      }
    });

    // 设置封面URL获取器（从缓存获取）
    handler.setArtUriGetter((song) {
      try {
        final cacheManager = _ref.read(cacheManagerProvider);
        final songInfo = cacheManager.getSongInfo(song);
        final pictureUrl = songInfo?.pictureUrl;
        if (pictureUrl != null && pictureUrl.isNotEmpty) {
          return Uri.parse(pictureUrl);
        }
      } catch (e) {
        _logger.w('获取歌曲封面失败: $e');
      }
      return null;
    });
  }

  AudioServiceRepeatMode _mapLoopMode(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return AudioServiceRepeatMode.none;
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  Future<void> _restoreCurrentSong(MyAudioHandler handler, PlayerState state) async {
    try {
      final savedSong = state.currentSong;
      if (savedSong == null || savedSong.isEmpty || _disposed) return;

      // 1. 初始竞态检查：如果当前状态已被用户操作改变（例如用户刚进App就切了歌），直接放弃恢复
      if (_currentState != null && _currentState!.currentSong != savedSong) {
        _logger.w('恢复中断：检测到新的播放状态');
        return;
      }

      // 确保 Handler 处于队列模式
      handler.switchToQueueMode();

      // 2. 准备恢复的数据
      // 如果保存的歌单为空，至少放入当前歌曲
      final playlist = state.playlist.isNotEmpty ? state.playlist : [savedSong];

      // 索引校正：确保索引指向正确的歌曲
      int index = state.currentIndex;
      if (index < 0 || index >= playlist.length || playlist[index] != savedSong) {
        // 索引失效或不匹配，尝试通过歌名查找
        index = playlist.indexOf(savedSong);
        // 还没找到？兜底回 0
        if (index == -1) index = 0;
      }
      final correctSong = playlist[index]; // 此时一定是有效的

      if (_disposed) return;

      // 3. 立即更新 UI 显示旧状态（让用户看到上次听的歌）
      _updateState(
        (_currentState ?? state).copyWith(
          playlist: playlist,
          currentIndex: index,
          currentSong: correctSong,
          duration: state.duration,
        ),
      );

      // 4. 准备音频源（耗时操作）
      final cacheManager = _ref.read(cacheManagerProvider);
      final dio = _ref.read(dioProvider);

      // 如果有播放列表，使用列表模式恢复（保持正确的索引）
      // 如果只有一首歌，使用单个音频源
      if (playlist.length > 1) {
        // 列表模式：构建所有音频源
        final List<AudioSource> audioSources = [];
        final List<String> validSongs = [];

        for (var name in playlist) {
          if (_disposed) return;
          final source = await _fetchAudioSource(
            name,
            cacheManager: cacheManager,
            dio: dio,
            allowNetworkFallback: true,
          );
          if (source != null) {
            audioSources.add(source);
            validSongs.add(name);
          }
        }

        // 5. 二次竞态检查：异步操作期间，用户可能切歌了
        if (_disposed || (_currentState != null && _currentState!.currentSong != correctSong)) {
          _logger.w('恢复中断：异步加载期间检测到新的播放状态');
          return;
        }

        // 6. 使用列表模式设置播放器（保持正确的索引）
        if (audioSources.isNotEmpty) {
          // 在 validSongs 中查找 correctSong 的索引（因为 validSongs 可能和 playlist 不同）
          int validIndex = validSongs.indexOf(correctSong);
          if (validIndex == -1) {
            // 如果找不到，使用原始索引（如果有效）
            validIndex = index < validSongs.length ? index : 0;
          }

          if (_disposed) return;
          await handler.loadPlaylist(
            audioSources,
            validIndex,
            initialPosition: state.position,
            autoPlay: state.isPlaying,
          );
          // 从缓存获取封面URL
          Uri? artUri;
          try {
            final songInfo = cacheManager.getSongInfo(correctSong);
            final pictureUrl = songInfo?.pictureUrl;
            if (pictureUrl != null && pictureUrl.isNotEmpty) {
              artUri = Uri.parse(pictureUrl);
            }
          } catch (e) {
            _logger.w('获取歌曲封面失败: $e');
          }
          handler.mediaItem.add(
            MediaItem(id: correctSong, title: correctSong, duration: state.duration, artUri: artUri),
          );

          if (_disposed) return;
          // 更新状态，使用 validSongs 和 validIndex
          _updateState(
            (_currentState ?? state).copyWith(
              playlist: validSongs,
              currentIndex: validIndex,
              currentSong: validSongs[validIndex],
            ),
          );

          await _syncFromHandler(handler, fallbackState: state);
        } else {
          _updateState((_currentState ?? state).copyWith(isPlaying: false));
        }
      } else {
        // 单曲模式：只准备当前歌曲的音频源
        final source = await _fetchAudioSource(
          correctSong,
          cacheManager: cacheManager,
          dio: dio,
          allowNetworkFallback: true,
        );

        // 5. 二次竞态检查：异步操作期间，用户可能切歌了
        if (_disposed || (_currentState != null && _currentState!.currentSong != correctSong)) {
          _logger.d('恢复中断：异步加载期间检测到新的播放状态');
          return;
        }

        // 6. 设置播放器（单曲模式）
        if (source != null) {
          if (_disposed) return;
          await handler.player.setAudioSource(source, initialPosition: state.position, preload: false);
          // 从缓存获取封面URL
          Uri? artUri;
          try {
            final songInfo = cacheManager.getSongInfo(correctSong);
            final pictureUrl = songInfo?.pictureUrl;
            if (pictureUrl != null && pictureUrl.isNotEmpty) {
              artUri = Uri.parse(pictureUrl);
            }
          } catch (e) {
            _logger.w('获取歌曲封面失败: $e');
          }
          handler.mediaItem.add(
            MediaItem(id: correctSong, title: correctSong, duration: state.duration, artUri: artUri),
          );

          if (state.isPlaying) {
            if (_disposed) return;
            await handler.player.play();
          }

          if (_disposed) return;
          await _syncFromHandler(handler, fallbackState: state);
        } else {
          _updateState((_currentState ?? state).copyWith(isPlaying: false));
        }
      }
    } catch (e) {
      _logger.e("恢复当前歌曲失败: $e");
    }
  }

  /// 从 Handler 同步实时播放状态（position, playing, duration）
  /// 注意：歌曲信息（currentSong, currentIndex）不从 Handler 读取，而是从 PlayerState 获取
  /// 这样可以确保 PlayerState 是唯一真实数据源，避免状态不一致
  Future<void> _syncFromHandler(MyAudioHandler handler, {PlayerState? fallbackState}) async {
    final current = _currentState ?? fallbackState ?? const PlayerState();

    // 只同步实时播放状态，不读取歌曲信息
    final playing = handler.player.playing;
    final pos = handler.player.position;
    final dur = handler.player.duration ?? current.duration;

    // 修复：歌曲信息从 PlayerState 获取（唯一真实数据源）
    // 如果播放器有当前索引，且我们有播放列表，从列表获取（最可靠）
    final idx = handler.player.currentIndex ?? current.currentIndex;
    String? title;
    if (idx >= 0 && current.playlist.isNotEmpty && idx < current.playlist.length) {
      title = current.playlist[idx];
    } else {
      // 否则使用当前状态中的歌曲
      title = current.currentSong;
    }

    // 修复：明确保留 loopMode 和 shuffleMode，不从 player 读取（避免恢复时被默认值覆盖）
    _updateState(
      current.copyWith(
        isPlaying: playing,
        position: pos,
        duration: dur,
        currentSong: title,
        currentIndex: idx,
        // 明确保留 loopMode 和 shuffleMode
        loopMode: current.loopMode,
        shuffleMode: current.shuffleMode,
      ),
    );
  }

  /// 恢复期间的事件抖动抑制：但一旦真正开始播放，就必须允许 position/isPlaying 等实时更新，
  /// 否则会出现"音乐在播但 UI 不动"的现象。
  /// [DEPRECATED] 移除抑制逻辑，允许实时状态穿透
  bool _shouldSuppressRealtimeUpdates() {
    return false;
  }

  Future<AudioSource?> _fetchAudioSource(
    String songName, {
    MusicCacheManager? cacheManager,
    Dio? dio,
    bool allowNetworkFallback = true,
  }) async {
    final MusicCacheManager cache = cacheManager ?? _ref.read(cacheManagerProvider);
    final client = _ref.read(apiClientProvider);
    final Dio dioClient = dio ?? _ref.read(dioProvider);

    // 尝试缓存
    final cachedInfo = cache.getSongInfo(songName);
    if (cachedInfo != null && cachedInfo.url.isNotEmpty) {
      return createCachedAudioSource(url: cachedInfo.url, songName: songName, cacheManager: cache, dio: dioClient);
    }

    if (allowNetworkFallback) {
      // 回退到接口
      try {
        final infos = await client.getMusicInfos([songName], false);
        final url = infos.firstOrNull?.url;
        if (url != null && url.isNotEmpty) {
          return createCachedAudioSource(url: url, songName: songName, cacheManager: cache, dio: dioClient);
        }
      } catch (e) {
        _logger.e("从接口获取歌曲信息失败: $e");
      }
    }

    return null;
  }

  void _setupStateListeners() {
    final handler = _handler;
    if (handler == null) return;

    _subs.add(
      handler.player.playerStateStream.map((s) => s.playing).distinct().listen((playing) {
        if (_shouldSuppressRealtimeUpdates()) return;
        _updateState((_currentState ?? const PlayerState()).copyWith(isPlaying: playing));
      }),
    );

    _subs.add(
      handler.player.positionStream.listen((position) {
        if (_shouldSuppressRealtimeUpdates()) return;
        _updateState((_currentState ?? const PlayerState()).copyWith(position: position));
      }),
    );

    _subs.add(
      handler.player.durationStream.listen((duration) {
        if (_shouldSuppressRealtimeUpdates()) return;
        // 允许更新为 0，确保切歌时 UI 能够感知时长变化
        final d = duration ?? Duration.zero;
        _updateState((_currentState ?? const PlayerState()).copyWith(duration: d));
      }),
    );

    // 兜底：当资源进入 ready，强制读取一次 duration（有些场景 durationStream 不稳定/延迟）
    _subs.add(
      handler.player.playerStateStream.listen((s) {
        if (_shouldSuppressRealtimeUpdates()) return;
        if (s.processingState == ProcessingState.ready) {
          final d = handler.player.duration;
          if (d != null && d > Duration.zero) {
            _updateState((_currentState ?? const PlayerState()).copyWith(duration: d));
          }
        }
      }),
    );

    _subs.add(
      handler.playbackState.map((s) => s.repeatMode).distinct().listen((repeatMode) {
        final loopMode = switch (repeatMode) {
          AudioServiceRepeatMode.none => LoopMode.off,
          AudioServiceRepeatMode.one => LoopMode.one,
          AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => LoopMode.all,
        };
        if (_shouldSuppressRealtimeUpdates()) return;
        _updateState((_currentState ?? const PlayerState()).copyWith(loopMode: loopMode));
      }),
    );

    _subs.add(
      handler.playbackState.map((s) => s.shuffleMode).distinct().listen((shuffleMode) {
        final enabled = shuffleMode == AudioServiceShuffleMode.all || shuffleMode == AudioServiceShuffleMode.group;
        if (_shouldSuppressRealtimeUpdates()) return;
        _updateState((_currentState ?? const PlayerState()).copyWith(shuffleMode: enabled));
      }),
    );

    // 移除 mediaItem 监听器：不再从 Handler 的 mediaItem 读取状态
    // PlayerState 是唯一真实数据源，Handler.mediaItem 只用于通知栏显示
    // 状态同步方向：PlayerState -> Handler.mediaItem（单向）

    // 注意：不再监听 playbackState.queueIndex，避免循环更新
    // 索引同步应该通过播放器的 currentIndexStream -> _onIndexChanged 回调来完成
    // 这样可以避免：_broadcastState() 更新 queueIndex -> 监听器更新 _currentState -> _getCurrentIndex 返回新值 -> 再次触发 _broadcastState() 的循环
  }

  void _updateState(PlayerState newState) {
    // 如果控制器已被销毁，不再更新状态
    if (_disposed) {
      return;
    }

    final oldState = _currentState;
    _currentState = newState;

    // 核心改进：PlayerState 是唯一真实数据源，主动同步到 Handler 的 mediaItem（用于通知栏显示）
    // 当歌曲或索引变化时，立即更新 mediaItem，确保通知栏显示正确
    final handler = _handler;
    if (handler != null) {
      final songChanged = oldState?.currentSong != newState.currentSong;
      final indexChanged = oldState?.currentIndex != newState.currentIndex;

      // 修复：当从 durationStream 获取到真实时长时（例如从0变为实际值），
      // 即使歌曲名没变，也需要更新 MediaItem 以显示进度条
      final oldDuration = oldState?.duration ?? Duration.zero;
      final newDuration = newState.duration;
      final durationChanged = newDuration > Duration.zero && newDuration != oldDuration;

      if (songChanged || indexChanged || durationChanged) {
        // 从 PlayerState 获取当前歌曲信息（唯一真实数据源）
        final currentSong = newState.currentSong;
        if (currentSong != null && currentSong.isNotEmpty) {
          // 从缓存获取封面URL
          Uri? artUri;
          try {
            final cacheManager = _ref.read(cacheManagerProvider);
            final songInfo = cacheManager.getSongInfo(currentSong);
            final pictureUrl = songInfo?.pictureUrl;
            if (pictureUrl != null && pictureUrl.isNotEmpty) {
              artUri = Uri.parse(pictureUrl);
            }
          } catch (e) {
            _logger.w('获取歌曲封面失败: $e');
          }

          // 单向同步：PlayerState -> Handler.mediaItem（仅用于通知栏显示）
          handler.mediaItem.add(
            MediaItem(
              id: currentSong,
              title: currentSong,
              duration: newState.duration > Duration.zero ? newState.duration : null,
              artUri: artUri, // 设置封面URI
            ),
          );
        }
      }
    }

    _stateUpdateCallback?.call(newState);
  }

  @override
  Future<PlayerState> getState() async {
    if (_currentState != null) {
      // 更新实时状态，但保留完整信息（playlist、currentPlaylistName等）
      final isPlaying = _handler?.player.playing ?? _currentState!.isPlaying;
      final position = _handler?.player.position ?? _currentState!.position;
      final duration = _handler?.player.duration ?? _currentState!.duration;
      // 修复：优先使用 _currentState 中的 loopMode 和 shuffleMode，而不是从 player 读取
      // 因为 player 的值可能在恢复过程中被重置为默认值，导致覆盖恢复的状态
      final loopMode = _currentState!.loopMode;
      final shuffleMode = _currentState!.shuffleMode;

      // 修复：歌曲信息从 PlayerState 获取（唯一真实数据源）
      // 如果播放器有当前索引，且我们有播放列表，从列表获取（最可靠）
      final idx = _handler?.player.currentIndex ?? _currentState!.currentIndex;
      String? currentSong;
      if (idx >= 0 && _currentState!.playlist.isNotEmpty && idx < _currentState!.playlist.length) {
        currentSong = _currentState!.playlist[idx];
      } else {
        currentSong = _currentState!.currentSong;
      }

      return _currentState!.copyWith(
        isPlaying: isPlaying,
        position: position,
        duration: duration,
        currentSong: currentSong,
        currentIndex: idx,
        loopMode: loopMode,
        shuffleMode: shuffleMode,
        // 保留原有的 playlist、currentPlaylistName 等信息
      );
    }

    // 首次获取状态（此时 _currentState 为 null，只能从 handler 获取）
    final isPlaying = _handler?.player.playing ?? false;
    final position = _handler?.player.position ?? Duration.zero;
    final duration = _handler?.player.duration ?? Duration.zero;
    final loopMode = _handler?.player.loopMode ?? LoopMode.off;
    final shuffleMode = _handler?.player.shuffleModeEnabled ?? false;
    final idx = _handler?.player.currentIndex ?? -1;

    // 首次获取时，只能从 mediaItem 获取（此时没有播放列表信息）
    // 但这是初始化场景，后续所有状态都从 PlayerState 获取
    final currentSong = _handler?.mediaItem.value?.title;

    final state = PlayerState(
      isPlaying: isPlaying,
      position: position,
      duration: duration,
      currentSong: currentSong,
      currentIndex: idx,
      loopMode: loopMode,
      shuffleMode: shuffleMode,
    );
    _currentState = state;
    return state;
  }

  @override
  Future<void> setStateUpdateCallback(void Function(PlayerState) callback) async {
    _stateUpdateCallback = callback;
  }

  @override
  Future<void> dispose() async {
    // 标记为已销毁，防止异步操作继续更新状态
    _disposed = true;
    // 清空回调，避免已销毁的控制器继续更新状态
    _stateUpdateCallback = null;

    // 注意：不停止播放器，因为 AudioPlayer 是 MyAudioHandler 的单例，本地和远程模式共享
    // 播放器的停止和模式切换由 setRemoteMode 统一管理

    // 创建副本以避免并发修改异常
    final subsCopy = List<StreamSubscription<dynamic>>.from(_subs);
    _subs.clear();

    // 取消定时关闭计时器
    _shutdownTimer?.cancel();
    _shutdownTimer = null;

    // 遍历副本取消订阅
    for (final sub in subsCopy) {
      try {
        await sub.cancel();
      } catch (e) {
        // 忽略取消订阅时的错误
        _logger.e("取消订阅时出错: $e");
      }
    }
  }

  @override
  Future<void> playSong(String songName, {String? playlistName}) async {
    try {
      if (playlistName != null && playlistName.isNotEmpty) {
        // 如果提供了歌单名称，则加载整个歌单并播放指定歌曲
        final songsResp = await _ref.read(cachedPlaylistMusicsProvider(playlistName).future);
        final songs = songsResp.musics;
        final index = songs.indexOf(songName);

        if (songs.isNotEmpty) {
          await playPlaylist(songs, playlistName: playlistName, initialIndex: index >= 0 ? index : 0);
          return;
        }
      }

      // 回退到原有的单曲播放逻辑
      _updateState(
        (_currentState ?? const PlayerState()).copyWith(
          currentSong: songName,
          currentPlaylistName: playlistName,
          playlist: [songName],
          currentIndex: 0,
          isPlaying: true, // 预期开始播放，先行更新UI
        ),
      );

      // 优先从缓存获取歌曲信息
      final cacheManager = _ref.read(cacheManagerProvider);
      final cachedInfo = cacheManager.getSongInfo(songName);

      // 如果缓存中有，构建单曲列表播放
      if (cachedInfo != null && cachedInfo.url.isNotEmpty) {
        // 复用 playPlaylist 逻辑，把它当作只有一个歌曲的列表
        // 这样可以统一使用列表模式管理
        await playPlaylist([songName], playlistName: playlistName, initialIndex: 0);
        return;
      }

      // 缓存中没有，从 API 获取
      final apiClient = _ref.read(apiClientProvider);
      final musicInfos = await apiClient.getMusicInfos([songName], false);
      if (musicInfos.isNotEmpty && musicInfos.first.url.isNotEmpty) {
        // 获取到信息后，同样走 playPlaylist 逻辑
        // 我们需要先把信息存入临时缓存或者让 playPlaylist 内部能获取到
        // 由于 playPlaylist 内部也会查缓存或补调API，我们只需再次确保能获取到
        // 这里最简单的做法是：不用单独调 playUrl，直接调 playPlaylist
        // 但为了防止 playPlaylist 内部查不到缓存又去调 API (多一次请求)，
        // 我们最好先把结果存入缓存 (虽然 cacheManager.saveSongInfos 是异步的，但内存通常很快)

        // 简单策略：直接调用 playPlaylist，它内部有补充逻辑
        await playPlaylist([songName], playlistName: playlistName, initialIndex: 0);
      }
    } catch (e) {
      _logger.e("本地播放失败: $e");
    }
  }

  @override
  Future<void> playPlaylistByName(String playlistName) async {
    try {
      // 从缓存获取歌单内容
      final cacheManager = _ref.read(cacheManagerProvider);
      final playlist = cacheManager.getPlaylist(playlistName);

      List<String> songs = [];
      if (playlist != null) {
        songs = playlist.songs;
      } else {
        // 如果缓存没有，尝试异步加载
        final songsResp = await _ref.read(cachedPlaylistMusicsProvider(playlistName).future);
        songs = songsResp.musics;
      }

      if (songs.isNotEmpty) {
        await playPlaylist(songs, playlistName: playlistName);
      }
    } catch (e) {
      _logger.e("本地播放歌单失败: $e");
    }
  }

  Future<void> playPlaylist(List<String> songNames, {String? playlistName, int initialIndex = 0}) async {
    // 优先从缓存获取歌曲信息，如果缓存中没有，才去请求API
    // 但根据需求1，getMusicInfos在打开app的时候已经初始化到缓存中了，不需要再调用接口查询
    // 可以批量从hive中拉取
    final cacheManager = _ref.read(cacheManagerProvider);
    // dio 用于后续可能的下载，这里暂时保留引用，以免需要时再 read
    // final dio = _ref.read(dioProvider);

    // 1. 批量获取歌曲信息
    // 直接从缓存获取所有歌曲信息
    final cachedInfos = cacheManager.getSongInfos(songNames);

    // 检查是否有缺失信息的歌曲（可能初始化未完成，或新添加的歌曲）
    // 虽然需求说不需要调用接口，但为了健壮性，如果真没有，还是得处理一下
    final missingSongs = songNames.where((name) => !cachedInfos.containsKey(name)).toList();
    if (missingSongs.isNotEmpty) {
      _logger.d('警告: 发现 ${missingSongs.length} 首歌曲未在缓存中，将尝试从API获取: ${missingSongs.take(3)}...');
      try {
        final apiClient = _ref.read(apiClientProvider);
        // 尝试补充获取缺失的歌曲信息
        final newInfos = await apiClient.getMusicInfos(missingSongs, false);
        for (var info in newInfos) {
          // 临时放入 map 中使用，不强制写入缓存以免影响流程速度
          // 或者也可以选择 cacheManager.saveSongInfos([SongInfoCache.fromApi(...)])
          // 这里简单起见，直接构造 SongInfoCache
          cachedInfos[info.name] = SongInfoCache(
            name: info.name,
            url: info.url,
            tags: info.tags,
            lastUpdated: DateTime.now(),
          );
        }
      } catch (e) {
        _logger.e("补充获取歌曲信息失败: $e");
      }
    }

    // 2. 构建列表音源
    final List<AudioSource> audioSources = [];
    final List<String> validSongs = [];
    final dio = _ref.read(dioProvider);

    for (var name in songNames) {
      final info = cachedInfos[name];
      if (info != null && info.url.isNotEmpty) {
        // 统一走 createCachedAudioSource：
        // - 若本地缓存文件已完整存在 -> 优先 AudioSource.file（更容易拿到 duration）
        // - 否则使用 LockCachingAudioSource 边下边播
        final source = await createCachedAudioSource(
          url: info.url,
          songName: name,
          cacheManager: cacheManager,
          dio: dio,
        );
        audioSources.add(source);
        validSongs.add(name);
      }
    }

    if (audioSources.isEmpty) {
      _logger.d('错误: 没有有效的音频源');
      return;
    }

    // 更新状态（使用 validSongs，排除无效歌曲）
    _updateState(
      (_currentState ?? const PlayerState()).copyWith(
        currentPlaylistName: playlistName,
        playlist: validSongs,
        currentIndex: initialIndex,
        currentSong: validSongs.isNotEmpty ? validSongs[initialIndex] : null,
        isPlaying: true,
      ),
    );

    // 3. 传递给 Handler（使用 setAudioSources）
    await _handler?.loadPlaylist(audioSources, initialIndex);
  }

  @override
  Future<void> playFromQueueIndex(int index) async {
    // 委托给 Handler 的 skipToIndex，支持列表模式的无缝跳转
    if (_handler != null) {
      await _handler.skipToIndex(index);

      // 更新状态 (虽然 Handler 的事件流也会更新，但立即更新 UI 更流畅)
      if (_currentState != null) {
        final playlist = _currentState!.playlist;
        if (index >= 0 && index < playlist.length) {
          _updateState(
            _currentState!.copyWith(currentIndex: index, currentSong: playlist[index], position: Duration.zero),
          );
        }
      }
    }
  }

  @override
  Future<void> playPause() async {
    if (_handler?.player.playing ?? false) {
      await _handler?.pause();
    } else {
      await _handler?.play();
    }

    // 兜底：即使恢复期间 stream 更新被抑制/延迟，也立即同步一次真实状态刷新 UI
    final handler = _handler;
    if (handler != null) {
      await _syncFromHandler(handler, fallbackState: _currentState);
    }
  }

  @override
  Future<void> skipNext() async {
    if (_handler != null) {
      await _handler.skipToNext();
    }
  }

  @override
  Future<void> skipPrevious() async {
    if (_handler != null) {
      await _handler.skipToPrevious();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_handler != null) {
      await _handler.seek(position);
    }
  }

  @override
  Future<void> toggleLoopMode() async {
    // 这里的逻辑也需要适配：不再直接调用 player.setLoopMode，而是调用 handler.setRepeatMode
    final currentMode = _currentState?.loopMode ?? LoopMode.off;
    final nextMode = switch (currentMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };

    final repeatMode = _mapLoopMode(nextMode);
    await _handler?.setRepeatMode(repeatMode);
  }

  @override
  Future<void> toggleShuffleMode() async {
    final enabled = !(_currentState?.shuffleMode ?? false);
    await _handler?.setShuffleMode(enabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none);
  }

  @override
  Future<void> togglePlayMode() async {
    final currentLoopMode = _currentState?.loopMode ?? LoopMode.off;
    final currentShuffleMode = _currentState?.shuffleMode ?? false;

    // 切换路径：全部循环 -> 随机播放 -> 单曲循环 -> 顺序播放 -> 全部循环
    if (currentShuffleMode) {
      // [随机播放] -> [单曲循环]
      // 关随机，开单曲
      // 注意：顺序很重要，先关 Shuffle 避免状态混乱，虽然 setRepeatMode 会覆盖逻辑，但为了稳妥分开调用
      await _handler?.setShuffleMode(AudioServiceShuffleMode.none);
      await _handler?.setRepeatMode(AudioServiceRepeatMode.one);
    } else {
      if (currentLoopMode == LoopMode.all) {
        // [全部循环] -> [随机播放]
        // 开启随机，同时保持 RepeatMode 为 All (实现随机无限播放)
        // 显式设置 All 以确保逻辑完备，即使当前已经是 All
        await _handler?.setRepeatMode(AudioServiceRepeatMode.all);
        await _handler?.setShuffleMode(AudioServiceShuffleMode.all);
      } else if (currentLoopMode == LoopMode.one) {
        // [单曲循环] -> [顺序播放]
        // 关单曲循环 (变为 None)
        await _handler?.setRepeatMode(AudioServiceRepeatMode.none);
      } else {
        // [顺序播放] -> [全部循环]
        // 开全部循环
        await _handler?.setRepeatMode(AudioServiceRepeatMode.all);
      }
    }
  }

  @override
  Future<void> setVolume(int volume) async {
    // 本地播放器不支持设置音量
  }

  Timer? _shutdownTimer;

  @override
  Future<void> sendShutdownCommand(int minutes) async {
    // 1. 取消旧的定时器（如果存在）
    _shutdownTimer?.cancel();
    _shutdownTimer = null;

    if (minutes <= 0) {
      _logger.i("取消定时暂停");
      return;
    }

    _logger.i("设置定时暂停: $minutes 分钟后");

    // 2. 创建新的定时器
    _shutdownTimer = Timer(Duration(minutes: minutes), () {
      if (_disposed) return;
      _logger.i("定时暂停生效");

      // 检查当前是否在播放，如果是则暂停
      if (_handler?.player.playing ?? false) {
        _handler?.pause();
      }

      _shutdownTimer = null;
    });
  }
}
