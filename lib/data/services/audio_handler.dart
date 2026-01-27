import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/data/providers/player/player_state.dart' as app_state;

final _logger = Logger();

/// 音频处理服务，用于后台播放
class MyAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription> _playerSubscriptions = [];

  // 核心：使用 List<AudioSource> 管理播放列表（列表模式启用时非空）
  List<AudioSource>? _playlistSources;

  // -------------------------
  // 托管模式 (Remote/Hosted Mode) 支持
  // -------------------------
  bool _isRemoteMode = false;

  // 外部注入的控制回调（当处于托管模式时调用）
  Future<void> Function()? _remotePlay;
  Future<void> Function()? _remotePause;
  Future<void> Function()? _remoteStop;
  Future<void> Function()? _remoteNext;
  Future<void> Function()? _remotePrevious;

  /// 切换模式
  /// [isRemote]: true=托管模式(UI和状态由外部注入), false=本地模式(驱动本地播放器)
  Future<void> setRemoteMode(bool isRemote) async {
    if (_isRemoteMode == isRemote) return;
    _isRemoteMode = isRemote;

    if (_isRemoteMode) {
      // 进入托管模式：
      // 1. 先停止播放器，确保 MediaCodec 资源完全释放，避免向已死亡的线程发送消息
      // 2. 停止本地状态广播（后续状态由 updateStateFromExternal 注入）
      try {
        await _player.stop();
        // 等待一小段时间，确保 MediaCodec 完全释放
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) {
        _logger.e('停止播放器时出错: $e');
      }

      // 3. 清除本地模式特有的回调，防止旧控制器干扰
      _audioSourceFetcher = null;
      _getPlaylist = null;
      _getCurrentIndex = null;
      _onIndexChanged = null;
    } else {
      // 回到本地模式：
      // 1. 立即广播一次本地状态
      _broadcastState();
    }
  }

  /// 设置托管模式下的控制回调
  void setRemoteCallbacks({
    Future<void> Function()? onPlay,
    Future<void> Function()? onPause,
    Future<void> Function()? onStop,
    Future<void> Function()? onNext,
    Future<void> Function()? onPrevious,
  }) {
    _remotePlay = onPlay;
    _remotePause = onPause;
    _remoteStop = onStop;
    _remoteNext = onNext;
    _remotePrevious = onPrevious;
  }

  /// 从外部更新状态（托管模式专用）
  /// 用于将远程设备的状态同步到系统通知栏
  /// [artUri] 可选的封面图片URI，如果不提供则尝试从其他方式获取
  Future<void> updateStateFromExternal(app_state.PlayerState state, {Uri? artUri}) async {
    if (!_isRemoteMode) return;

    // 1. 更新 MediaItem
    if (state.currentSong != null && state.currentSong!.isNotEmpty) {
      final newItem = MediaItem(
        id: state.currentSong!,
        title: state.currentSong!,
        artist: state.currentPlaylistName ?? 'Remote Device',
        duration: state.duration > Duration.zero ? state.duration : null,
        artUri: artUri, // 使用传入的封面URI
      );
      // 仅当内容变化时才更新，避免闪烁
      // 注意：MediaItem 的 == 操作符会比较所有字段（包括 artUri），所以如果封面从有变无，也会触发更新
      if (mediaItem.value != newItem) {
        mediaItem.add(newItem);
      }
    }

    // 2. 映射播放状态
    // Remote LoopMode -> AudioServiceRepeatMode
    final repeatMode = switch (state.loopMode) {
      LoopMode.off => AudioServiceRepeatMode.none,
      LoopMode.one => AudioServiceRepeatMode.one,
      LoopMode.all => AudioServiceRepeatMode.all,
    };

    // Remote Shuffle -> AudioServiceShuffleMode
    final shuffleMode = state.shuffleMode ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;

    // 3. 更新 PlaybackState
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (state.isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          // 远程模式下通常不显示 stop，或者视需求而定
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.playPause,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: AudioProcessingState.ready, // 远程模式默认为 ready
        playing: state.isPlaying,
        updatePosition: state.position,
        bufferedPosition: state.position, // 远程无法获取缓冲，暂设为当前位置
        speed: 1.0,
        queueIndex: state.currentIndex,
        repeatMode: repeatMode,
        shuffleMode: shuffleMode,
      ),
    );
  }

  // -------------------------
  // 原有逻辑
  // -------------------------
  int _currentRequestId = 0; // 内部请求ID，用于防止并发竞争

  /// 获取并递增请求 ID
  int _getNextRequestId() => ++_currentRequestId;

  /// 检查请求是否仍然有效
  bool _isRequestValid(int requestId) => requestId == _currentRequestId;

  // 懒加载播放列表支持 - 通过回调从外部获取，不再内部维护
  Future<AudioSource?> Function(String song)? _audioSourceFetcher;
  // 获取封面URL的回调（从外部缓存获取）
  Uri? Function(String song)? _getArtUri;
  // 获取播放列表和当前索引的回调（从外部统一数据源获取）
  List<String> Function()? _getPlaylist;
  int Function()? _getCurrentIndex;
  // 更新索引的回调（用于同步到外部统一数据源）
  void Function(int index)? _onIndexChanged;

  void setAudioSourceFetcher(Future<AudioSource?> Function(String) fetcher) {
    _audioSourceFetcher = fetcher;
  }

  /// 设置封面URL获取器（从外部缓存获取）
  void setArtUriGetter(Uri? Function(String song) getter) {
    _getArtUri = getter;
  }

  /// 设置播放列表和索引的获取器（从外部统一数据源）
  void setPlaylistGetter({
    required List<String> Function() getPlaylist,
    required int Function() getCurrentIndex,
    void Function(int index)? onIndexChanged,
  }) {
    _getPlaylist = getPlaylist;
    _getCurrentIndex = getCurrentIndex;
    _onIndexChanged = onIndexChanged;
  }

  MyAudioHandler() {
    _initAudioSession();
    _initPlayerListeners();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // 显式激活 AudioSession，这对 iOS 后台播放至关重要
    await session.setActive(true);

    // 监听音频打断事件 (如电话呼入、其他App占用音频焦点)
    // 核心原则：
    // 1. just_audio 会自动处理播放暂停/恢复，我们不需要手动干预
    // 2. 只需要监听并更新状态栏显示，确保状态栏与实际播放状态一致
    // 3. 不手动调用 pause()/play()，避免与 just_audio 的内部逻辑冲突
    session.interruptionEventStream.listen((event) {
      // 远程模式下，手机端的音频焦点变化不应影响远程设备
      if (_isRemoteMode) return;

      if (event.begin) {
        // 打断开始：just_audio 会自动暂停，我们只需要更新状态栏
        _logger.d('音频被打断，just_audio 会自动处理，更新状态栏');
        // 延迟一点更新，确保 just_audio 已经处理完暂停
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isRemoteMode) {
            _broadcastState();
          }
        });
      } else {
        // 打断结束：just_audio 可能会自动恢复，也可能不会（取决于配置）
        // 我们只更新状态栏，不手动恢复播放（避免冲突）
        _logger.d('音频打断结束，更新状态栏');
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_isRemoteMode) {
            _broadcastState();
          }
        });
      }
    });

    // 监听耳机拔出等变得“嘈杂”的事件 (Becoming Noisy)
    // 通常在拔出耳机时触发，标准行为是暂停播放
    session.becomingNoisyEventStream.listen((_) {
      if (!_isRemoteMode && _player.playing) {
        _logger.d('检测到 Becoming Noisy 事件，暂停播放并更新状态栏');
        pause(); // pause() 内部会调用 _broadcastState()
      }
    });
  }

  void _initPlayerListeners() {
    // 监听关键状态变化，而不是所有 playbackEventStream 事件
    // 使用 distinct() 过滤重复状态，避免不必要的更新
    // 参考 local_player_controller.dart 的做法

    // 1. 监听播放状态变化（playing）- 立即更新状态栏
    _playerSubscriptions.add(
      _player.playerStateStream.map((s) => s.playing).distinct().listen((playing) {
        _logger.d('播放状态变化: $playing，立即更新状态栏');
        _broadcastState();
      }),
    );

    // 2. 监听处理状态变化（processingState）
    _playerSubscriptions.add(
      _player.playerStateStream.map((s) => s.processingState).distinct().listen((_) => _broadcastState()),
    );

    // 3. 监听索引变化（currentIndex）
    _playerSubscriptions.add(_player.currentIndexStream.distinct().listen((_) => _broadcastState()));

    // 4. 位置更新：模仿对方的逻辑，使用流监听 + 节流 (Throttling)
    // 避免过于频繁的更新导致系统压力，同时保证进度条平滑
    DateTime? lastUpdateTime;
    _playerSubscriptions.add(
      _player.positionStream.listen((position) {
        final now = DateTime.now();
        if (lastUpdateTime == null || now.difference(lastUpdateTime!) > const Duration(milliseconds: 800)) {
          lastUpdateTime = now;
          if (!_isRemoteMode && _player.playing) {
            _broadcastState();
          }
        }
      }),
    );

    // 监听索引变化 (针对列表播放模式)
    _playerSubscriptions.add(
      _player.currentIndexStream.listen((index) {
        if (_playlistSources != null && index != null) {
          // 如果是列表模式，需要反向同步索引到外部
          // 注意：_onIndexChanged 是外部提供的回调，用于更新外部状态
          // 这里的 index 是播放器内部的实际索引
          _onIndexChanged?.call(index);
        }
      }),
    );

    // 监听播放完成，自动播放下一首
    _playerSubscriptions.add(
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _handlePlaybackCompleted();
        }
      }),
    );

    // 监听播放错误（通过 playerStateStream 无法直接获取错误，但可通过 playbackEventStream 获取）
    _playerSubscriptions.add(
      _player.playbackEventStream.listen(
        (event) {},
        onError: (Object e, StackTrace st) {
          final msg = e.toString();

          // 1. 忽略预期的网络中断（切歌/停止时常见）
          if (msg.contains('SocketException') ||
              msg.contains('Socket closed') ||
              msg.contains('Connection aborted') ||
              msg.contains('Broken pipe')) {
            _logger.i('忽略预期的网络中断 (切歌/停止时常见): $msg');
            return;
          }

          // 2. 检测到缓存代理失败，尝试降级到在线播放
          // "Proxy request failed: 200" 是 just_audio_background 或 LockCachingAudioSource 的典型错误
          if (msg.contains('Proxy request failed') || msg.contains('502 Bad Gateway')) {
            _logger.w('检测到缓存代理失败，尝试降级到在线播放: $msg');
            _attemptFallbackForCurrentItem();
            return;
          }

          _logger.e('播放器发生错误: $e');
          // 关键修复：发生错误时，必须更新 playbackState，否则 UI 会认为还在播放
          playbackState.add(
            playbackState.value.copyWith(
              processingState: AudioProcessingState.error,
              playing: false, // 强制标记为停止
            ),
          );

          // 尝试自动恢复或跳过
          if (_player.playing && _playlistSources != null) {
            _logger.i('尝试跳过错误歌曲...');
            if (_player.hasNext) {
              _player.seekToNext();
            }
          }
        },
      ),
    );
  }

  /// 尝试为当前出错的歌曲降级播放（从缓存源降级为普通URL源）
  Future<void> _attemptFallbackForCurrentItem() async {
    try {
      if (_playlistSources == null) return;
      final index = _player.currentIndex;
      if (index == null || index < 0 || index >= _playlistSources!.length) return;

      final source = _playlistSources![index];
      // 检查是否为缓存源
      if (source is LockCachingAudioSource) {
        _logger.i('尝试将第 $index 首歌曲 (${source.tag?.title}) 降级为在线播放...');

        // 创建降级源（直接使用 URL，绕过缓存代理）
        final fallbackSource = AudioSource.uri(
          source.uri,
          tag: source.tag, // 保留元数据
        );

        // 更新本地列表
        _playlistSources![index] = fallbackSource;

        // 重新加载播放列表，保持当前进度
        // 注意：这会重建播放列表，可能会有短暂的停顿
        final position = _player.position;
        // 既然发生错误了，我们通常希望自动恢复播放
        const shouldPlay = true;

        // 使用 ConcatenatingAudioSource 重新设置播放源
        await _player.setAudioSource(
          ConcatenatingAudioSource(children: _playlistSources!),
          initialIndex: index,
          initialPosition: position,
        );

        if (shouldPlay) {
          _player.play();
        }
        _logger.i('已成功降级并恢复播放');
      }
    } catch (e) {
      _logger.e('降级重试失败: $e');
      // 如果降级也失败了，那就真的失败了，让 error listener 处理（或者手动设置 error 状态）
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error));
    }
  }

  /// 取消所有流订阅，防止内存泄漏
  /// 通常 AudioHandler 随应用生命周期存在，但在热重载或特殊销毁场景下有用
  void dispose() {
    for (final s in _playerSubscriptions) {
      s.cancel();
    }
    _playerSubscriptions.clear();
    _player.dispose();
  }

  /// 广播播放状态到系统通知栏（状态栏）
  /// 核心原则：
  /// 1. 本地模式：从播放器读取真实状态并广播
  /// 2. 远程模式：禁止本地广播，状态由 updateStateFromExternal 注入
  /// 3. 确保状态栏显示与实际播放状态完全一致
  void _broadcastState() {
    // 托管模式下，状态由外部注入，禁止本地广播覆盖
    if (_isRemoteMode) return;

    // 获取当前索引：列表模式优先使用播放器内部索引，队列模式使用外部回调
    final int currentIndex;
    if (_playlistSources != null) {
      // 列表模式：优先使用播放器内部索引（最准确）
      currentIndex = _player.currentIndex ?? 0;
    } else {
      // 队列模式：使用外部回调获取索引
      if (_getCurrentIndex == null) return; // 队列模式必须要有回调
      currentIndex = _getCurrentIndex!();
    }
    // 调试日志：确认播放按钮状态
    final isPlaying = _player.playing;
    // _logger.d(
    //   '广播状态: \n _playlistSources: ${_playlistSources?.length}\n _player.currentIndex: ${_player.currentIndex}\n _getCurrentIndex: ${_getCurrentIndex?.call()} \n currentIndex: $currentIndex',
    // );
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.playPause,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: isPlaying,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: currentIndex,
        // 修复：直接使用内部维护的 _currentRepeatMode，因为底层 loopMode 可能被强制设为 off
        repeatMode: _currentRepeatMode,
        shuffleMode: _player.shuffleModeEnabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      ),
    );
  }

  void _handlePlaybackCompleted() {
    // 如果使用列表模式，由播放器自动管理播放顺序，无需手动干预
    if (_playlistSources != null) return;

    // 自动播放下一首
    // 注意：如果是单曲循环 (LoopMode.one)，just_audio 会自动 seek 到 0 并继续播放，不会进入 completed 状态
    // 如果进入了 completed 状态，说明 LoopMode 是 off (或者我们手动干预了)

    final playlist = _getPlaylist?.call() ?? [];
    if (playlist.isEmpty) return;

    final currentIndex = _getCurrentIndex?.call() ?? 0;
    int nextIndex = -1;

    if (_player.shuffleModeEnabled) {
      final random = Random();
      if (playlist.length > 1) {
        do {
          nextIndex = random.nextInt(playlist.length);
        } while (nextIndex == currentIndex);
      } else {
        nextIndex = 0;
      }
    } else {
      if (currentIndex < playlist.length - 1) {
        nextIndex = currentIndex + 1;
      } else {
        // 列表循环
        if (_currentRepeatMode == AudioServiceRepeatMode.all) {
          nextIndex = 0;
        }
      }
    }

    if (nextIndex != -1) {
      _playByContext(nextIndex, playlist);
    } else {
      // 列表播完，停止
      _player.stop();
      _player.seek(Duration.zero);
    }
  }

  // 内部维护的播放模式状态，用于逻辑判断
  AudioServiceRepeatMode _currentRepeatMode = AudioServiceRepeatMode.none;

  AudioPlayer get player => _player;

  /// 播放控制：响应状态栏播放按钮点击
  /// 本地模式：调用播放器 play() 并立即更新状态栏
  /// 远程模式：转发给远程回调
  @override
  Future<void> play() async {
    try {
      if (_isRemoteMode) {
        await _remotePlay?.call();
      } else {
        // 修复：如果播放器由于各种原因（如被系统打断后未正确恢复）处于 completed 状态
        // 直接调用 play() 可能无效，需要先 seek 到开头
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
        // 立即更新状态栏，确保通知栏按钮状态正确（从播放变为暂停按钮）
        _broadcastState();
      }
    } catch (e, stackTrace) {
      _logger.e('播放失败: $e');
      _logger.e('堆栈: $stackTrace');
      // 更新状态为错误，但不抛出异常，避免崩溃
      playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error));
    }
  }

  /// 暂停控制：响应状态栏暂停按钮点击
  /// 本地模式：调用播放器 pause() 并立即更新状态栏
  /// 远程模式：转发给远程回调
  @override
  Future<void> pause() async {
    try {
      if (_isRemoteMode) {
        await _remotePause?.call();
      } else {
        await _player.pause();
        // 立即更新状态栏，确保通知栏按钮状态正确（从暂停变为播放按钮）
        _broadcastState();
      }
    } catch (e, stackTrace) {
      _logger.e('暂停失败: $e');
      _logger.e('堆栈: $stackTrace');
    }
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    _logger.d('收到媒体按键点击: $button');
    switch (button) {
      case MediaButton.media:
        // 处理耳机线控或蓝牙耳机的播放/暂停键
        if (playbackState.value.playing) {
          await pause();
        } else {
          await play();
        }
        break;
      case MediaButton.next:
        await skipToNext();
        break;
      case MediaButton.previous:
        await skipToPrevious();
        break;
    }
  }

  Future<void> playPause() async {
    _logger.d('收到 playPause 请求');
    if (playbackState.value.playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (_isRemoteMode) {
        await _remoteStop?.call();
      } else {
        await _player.stop();
        // 立即更新状态栏，确保通知栏按钮状态正确
        _broadcastState();
      }
      await super.stop();
    } catch (e, stackTrace) {
      _logger.e('停止失败: $e');
      _logger.e('堆栈: $stackTrace');
      // 即使停止失败，也尝试调用 super.stop()
      try {
        await super.stop();
      } catch (e2) {
        _logger.e('super.stop() 也失败: $e2');
      }
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
      // 手动广播一次状态，确保进度条立即跳变
      _broadcastState();
    } catch (e, stackTrace) {
      _logger.e('跳转失败: $e');
      _logger.e('堆栈: $stackTrace');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
      // 手动广播一次状态，确保速度变化立即反映
      _broadcastState();
    } catch (e, stackTrace) {
      _logger.e('设置播放速度失败: $e');
      _logger.e('堆栈: $stackTrace');
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _currentRepeatMode = repeatMode;
    if (_isRemoteMode) {
      // 托管模式下，模式切换通常由外部 UI 触发并通过 updateStateFromExternal 同步给系统。
      // 如果是系统/通知栏触发的 setRepeatMode，这里暂不处理或待实现远程同步。
      return;
    }
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        // 如果使用列表模式，直接使用原生 LoopMode.all
        if (_playlistSources != null) {
          await _player.setLoopMode(LoopMode.all);
        } else {
          // 兼容旧模式（单曲源）：列表循环模式下，必须把底层设为 off，靠手动切歌
          await _player.setLoopMode(LoopMode.off);
        }
        break;
    }
    _broadcastState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    if (_isRemoteMode) return;
    if (shuffleMode == AudioServiceShuffleMode.none) {
      await _player.setShuffleModeEnabled(false);
    } else {
      await _player.setShuffleModeEnabled(true);
      // 如果使用列表模式，Shuffle 启用后不需要手动重排 sources，
      // just_audio 的 setShuffleModeEnabled(true) 会维护内部的随机索引列表。
    }
    _broadcastState();
  }

  /// 切换到队列模式（非列表源模式），清除内部列表引用
  void switchToQueueMode() {
    _playlistSources = null;
  }

  /// 播放 AudioSource (支持缓存等高级特性)
  Future<void> playSource(AudioSource source, {String? title, String? id}) async {
    final requestId = _getNextRequestId();
    // 托管模式下拦截
    if (_isRemoteMode) {
      _logger.w('托管模式下拦截了本地 playSource 调用');
      return;
    }
    try {
      // 在播放新歌前，先停止当前播放
      if (_player.playing || _player.processingState != ProcessingState.idle) {
        try {
          await _player.stop();
          if (!_isRequestValid(requestId)) return;
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          _logger.w('停止播放器时出错: $e');
        }
      }

      if (!_isRequestValid(requestId)) return;

      // 切换到单曲模式，清空播放列表引用
      switchToQueueMode();

      // 在播放新歌时，确保 LoopMode 正确
      if (_currentRepeatMode == AudioServiceRepeatMode.all) {
        await _player.setLoopMode(LoopMode.off);
      }

      await _player.setAudioSource(source);
      if (!_isRequestValid(requestId)) return;

      // 设置媒体项信息
      final songName = title ?? 'unknown';
      final artUri = _getArtUri?.call(songName);
      mediaItem.add(MediaItem(id: id ?? 'unknown', title: title ?? 'Unknown', artUri: artUri));

      await _player.play();
    } catch (e, stackTrace) {
      if (_isRequestValid(requestId)) {
        _logger.e('播放 AudioSource 失败: $e');
        _logger.e('堆栈: $stackTrace');
        playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error));
      }
    }
  }

  /// 播放音乐 URL
  Future<void> playUrl(String url, {String? title}) async {
    await playSource(AudioSource.uri(Uri.parse(url)), title: title, id: url);
  }

  /// 播放播放列表 (懒加载模式)
  Future<void> playPlaylist({required List<String> titles, int initialIndex = 0}) async {
    try {
      // 兼容旧的队列信息更新（可选，因为现在主要依赖 playlistSource）
      final mediaItems = titles.map((title) {
        return MediaItem(id: title, title: title);
      }).toList();
      queue.add(mediaItems);

      // 注意：这里不再调用 _playCurrent，而是等待外部调用 loadPlaylist
      // 为了兼容旧代码，如果没有调用 loadPlaylist，则保持原样
      if (_playlistSources == null) {
        // 如果没有列表模式，回退到旧模式
        // 但我们现在的目标是全面迁移到 loadPlaylist
      }
    } catch (e) {
      _logger.e('设置播放列表失败: $e');
      rethrow;
    }
  }

  /// 加载列表（支持初始索引和起始进度，可选择是否自动播放）
  Future<void> loadPlaylist(
    List<AudioSource> sources,
    int initialIndex, {
    Duration? initialPosition,
    bool autoPlay = true,
  }) async {
    final requestId = _getNextRequestId();
    // 托管模式下禁止驱动本地播放器
    if (_isRemoteMode) {
      _logger.w('托管模式下拦截了本地 loadPlaylist 调用');
      return;
    }
    _playlistSources = sources;
    try {
      // 在加载新列表前，先停止当前播放，确保 MediaCodec 资源完全释放
      // 注意：如果是快速切歌，这里的 stop 可能已经在之前的请求中执行过了
      if (_player.playing || _player.processingState != ProcessingState.idle) {
        try {
          await _player.stop();
          if (!_isRequestValid(requestId)) return;
          // 仅在必要时才等待，减少切换延迟
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          _logger.w('停止播放器时出错（可忽略）: $e');
        }
      }

      if (!_isRequestValid(requestId)) return;

      // 确保 LoopMode 正确
      switch (_currentRepeatMode) {
        case AudioServiceRepeatMode.none:
          await _player.setLoopMode(LoopMode.off);
          break;
        case AudioServiceRepeatMode.one:
          await _player.setLoopMode(LoopMode.one);
          break;
        case AudioServiceRepeatMode.all:
        case AudioServiceRepeatMode.group:
          await _player.setLoopMode(LoopMode.all);
          break;
      }

      if (!_isRequestValid(requestId)) return;

      await _player.setAudioSources(
        sources,
        initialIndex: initialIndex,
        initialPosition: initialPosition ?? Duration.zero,
      );

      if (autoPlay && _isRequestValid(requestId)) {
        await _player.play();
      }
    } catch (e, stackTrace) {
      if (_isRequestValid(requestId)) {
        _logger.e('加载播放列表失败: $e');
        _logger.e('堆栈: $stackTrace');
        playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error));
      }
    }
  }

  /// 核心播放逻辑：播放指定索引的歌曲
  Future<void> _playByContext(int index, List<String> playlist) async {
    if (index < 0 || index >= playlist.length) return;
    if (_isRemoteMode) return;

    final requestId = _getNextRequestId();
    final songName = playlist[index];

    // 1. 立即更新外部索引，确保 UI 响应
    _onIndexChanged?.call(index);

    // 2. 更新 MediaItem 占位
    final artUri = _getArtUri?.call(songName);
    mediaItem.add(MediaItem(id: songName, title: songName, duration: null, artUri: artUri));

    // 3. 广播加载状态
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
        queueIndex: index,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
      ),
    );

    try {
      // 4. 获取音频源
      final source = await _audioSourceFetcher?.call(songName);
      if (!_isRequestValid(requestId)) return;

      if (source != null) {
        // 在播放新歌前，先停止当前播放
        if (_player.playing || _player.processingState != ProcessingState.idle) {
          try {
            await _player.stop();
            if (!_isRequestValid(requestId)) return;
            await Future.delayed(const Duration(milliseconds: 50));
          } catch (e) {
            _logger.w('停止播放器时出错: $e');
          }
        }

        if (!_isRequestValid(requestId)) return;

        // 确保单曲模式下的 LoopMode 设置
        if (_currentRepeatMode == AudioServiceRepeatMode.all) {
          await _player.setLoopMode(LoopMode.off);
        }

        await _player.setAudioSource(source);
        if (!_isRequestValid(requestId)) return;

        await _player.play();
      } else {
        _logger.e('获取歌曲 AudioSource 失败: $songName');
        await stop();
      }
    } catch (e, stackTrace) {
      if (_isRequestValid(requestId)) {
        _logger.e('播放出错 ($songName): $e');
        _logger.e('堆栈: $stackTrace');
        playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.error));
        await stop();
      }
    }
  }

  /// 在"当前队列"内跳转到指定索引并播放
  Future<void> skipToIndex(int index) async {
    // 托管模式下转发/拦截
    if (_isRemoteMode) {
      _logger.w('托管模式下拦截了本地 skipToIndex 调用');
      return;
    }

    // 如果是列表模式
    if (_playlistSources != null) {
      if (index >= 0 && index < (_playlistSources!.length)) {
        await _player.seek(Duration.zero, index: index);
        if (!_player.playing) {
          await _player.play();
        }
      }
      return;
    }

    final playlist = _getPlaylist?.call() ?? [];
    if (playlist.isEmpty) return;
    if (index < 0 || index >= playlist.length) return;

    await _playByContext(index, playlist);
  }

  @override
  Future<void> skipToNext() async {
    // 托管模式：转发给外部回调
    if (_isRemoteMode) {
      await _remoteNext?.call();
      return;
    }

    // 如果是列表模式
    if (_playlistSources != null) {
      if (_player.hasNext) {
        await _player.seekToNext();
        if (!_player.playing) {
          await _player.play();
        }
      }
      return;
    }

    final playlist = _getPlaylist?.call() ?? [];
    if (playlist.isEmpty) return;

    final currentIndex = _getCurrentIndex?.call() ?? 0;
    int nextIndex;

    if (_player.shuffleModeEnabled) {
      // 简单随机逻辑
      final random = Random();
      if (playlist.length > 1) {
        do {
          nextIndex = random.nextInt(playlist.length);
        } while (nextIndex == currentIndex);
      } else {
        nextIndex = 0;
      }
    } else {
      if (currentIndex < playlist.length - 1) {
        nextIndex = currentIndex + 1;
      } else {
        // 列表结束
        if (_currentRepeatMode == AudioServiceRepeatMode.all) {
          nextIndex = 0;
        } else {
          await stop();
          return;
        }
      }
    }

    await _playByContext(nextIndex, playlist);
  }

  @override
  Future<void> skipToPrevious() async {
    // 托管模式：转发给外部回调
    if (_isRemoteMode) {
      await _remotePrevious?.call();
      return;
    }

    // 如果是列表模式
    if (_playlistSources != null) {
      if (_player.hasPrevious) {
        await _player.seekToPrevious();
        if (!_player.playing) {
          await _player.play();
        }
      } else {
        await _player.seek(Duration.zero);
        if (!_player.playing) {
          await _player.play();
        }
      }
      return;
    }

    final playlist = _getPlaylist?.call() ?? [];
    if (playlist.isEmpty) return;

    final currentIndex = _getCurrentIndex?.call() ?? 0;
    int prevIndex;

    // 如果播放超过3秒，重播当前歌曲
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_player.shuffleModeEnabled) {
      final random = Random();
      if (playlist.length > 1) {
        do {
          prevIndex = random.nextInt(playlist.length);
        } while (prevIndex == currentIndex);
      } else {
        prevIndex = 0;
      }
    } else {
      if (currentIndex > 0) {
        prevIndex = currentIndex - 1;
      } else {
        // 列表开头
        if (_currentRepeatMode == AudioServiceRepeatMode.all) {
          prevIndex = playlist.length - 1;
        } else {
          await seek(Duration.zero);
          return;
        }
      }
    }

    await _playByContext(prevIndex, playlist);
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }
}
