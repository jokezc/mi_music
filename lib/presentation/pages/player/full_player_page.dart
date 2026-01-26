import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/core/utils/favorite_utils.dart';
import 'package:mi_music/core/utils/permission_utils.dart';
import 'package:mi_music/core/utils/snackbar_utils.dart';
import 'package:mi_music/core/utils/song_utils.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';
import 'package:mi_music/presentation/widgets/device_selector_sheet.dart';
import 'package:mi_music/presentation/widgets/play_queue_sheet.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final _logger = Logger();

/// 全屏播放页面
class FullPlayerPage extends StatelessWidget {
  const FullPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部工具栏固定
            const _PlayerAppBar(),
            Expanded(child: _PlayerBody()),
            // 底部操作栏固定显示（收藏/队列/分享等）
            const _PlayerActions(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// 中间主体区域：不滚动，自适应缩放封面/间距，避免小屏溢出
class _PlayerBody extends StatelessWidget {
  const _PlayerBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        // 水平 padding 随屏宽变化（16~40）
        final horizontalPadding = (w * 0.10).clamp(16.0, 40.0);
        // 封面大小随可用高度变化（160~280）
        final coverSize = (h * 0.40).clamp(160.0, 280.0);
        // 间距随高度缩放
        final gapL = (h * 0.07).clamp(18.0, 48.0);
        final gapM = (h * 0.05).clamp(12.0, 32.0);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlayerCover(size: coverSize, horizontalMargin: horizontalPadding),
              SizedBox(height: gapL),
              _PlayerInfo(horizontalPadding: horizontalPadding),
              SizedBox(height: gapL),
              _PlayerProgress(horizontalPadding: horizontalPadding),
              SizedBox(height: gapM),
              _PlayerControls(horizontalPadding: horizontalPadding),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerAppBar extends ConsumerWidget {
  const _PlayerAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentDevice = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentDevice));
    final isLocalMode = currentDevice?.type == DeviceType.local;
    final currentSong = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentSong));
    final currentPlaylistName = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentPlaylistName));
    final isCustomPlaylist = SongUtils.isCustomPlaylist(ref, currentPlaylistName ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 左右按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                onPressed: () => Navigator.pop(context),
                tooltip: '关闭',
              ),
              // 右侧按钮组
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 设备切换按钮
                  IconButton(
                    icon: Icon(
                      isLocalMode ? Icons.smartphone_rounded : Icons.speaker_rounded,
                      color: !isLocalMode
                          ? AppColors.primary
                          : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                    onPressed: () => _showDeviceSelector(context, ref),
                    tooltip: '切换设备',
                  ),
                  // 更多菜单
                  if (currentSong != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.ac_unit_rounded, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      tooltip: '更多',
                      offset: const Offset(0, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'delete') {
                          SongUtils.deleteSong(context, ref, currentSong);
                        } else if (value == 'remove') {
                          if (currentPlaylistName != null) {
                            SongUtils.removeSongFromPlaylist(context, ref, currentSong, currentPlaylistName);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        if (isCustomPlaylist)
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.remove_circle_rounded, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('从歌单移除'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, color: Colors.red),
                              SizedBox(width: 8),
                              Text('永久删除歌曲', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          // 中间显示设备名称（仅远程设备显示，绝对居中）
          if (currentDevice?.name != null)
            Center(
              child: Text(
                currentDevice!.name!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  void _showDeviceSelector(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const DeviceSelectorSheet(),
    );
  }
}

class _PlayerCover extends ConsumerWidget {
  final double size;
  final double horizontalMargin;

  const _PlayerCover({this.size = 280, this.horizontalMargin = 40});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch only isPlaying to toggle animation
    final currentSong = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentSong));

    // 获取歌曲图片
    final cacheManager = ref.watch(cacheManagerProvider);
    final songInfo = currentSong != null ? cacheManager.getSongInfo(currentSong) : null;
    final pictureUrl = songInfo?.pictureUrl;

    return Hero(
      tag: 'player_cover',
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
        decoration: BoxDecoration(
          gradient: pictureUrl == null ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 20)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: pictureUrl != null && pictureUrl.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: pictureUrl,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                    child: Icon(Icons.music_note_rounded, size: (size * 0.43).clamp(84.0, 120.0), color: Colors.white),
                  ),
                )
              : Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  child: Icon(Icons.music_note_rounded, size: (size * 0.43).clamp(84.0, 120.0), color: Colors.white),
                ),
        ),
      ),
    );
  }
}

class _PlayerInfo extends ConsumerWidget {
  final double horizontalPadding;

  const _PlayerInfo({this.horizontalPadding = 40});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch specific fields to avoid unnecessary rebuilds
    final currentSong = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentSong));
    final currentPlaylistName = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentPlaylistName));

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 只显示歌单名称，如果没有则不显示
    final displayText = currentPlaylistName?.isNotEmpty == true ? currentPlaylistName : "";

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          // 歌曲名称显示（超出部分显示省略号）
          Text(
            currentSong ?? S.notPlaying,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // 只在有歌单名称时显示
          if (displayText != null) ...[
            const SizedBox(height: 8),
            Text(
              displayText,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerProgress extends ConsumerWidget {
  final double horizontalPadding;

  const _PlayerProgress({this.horizontalPadding = 40});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch position and duration
    final position = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.position ?? Duration.zero));
    final duration = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.duration ?? Duration.zero));
    final isLocalMode = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.isLocalMode ?? true));

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              thumbColor: AppColors.primary,
              disabledThumbColor: AppColors.primary,
              disabledActiveTrackColor: AppColors.primary,
              disabledInactiveTrackColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
            ),
            child: Slider(
              value: duration.inMilliseconds > 0
                  ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                  : 0,
              onChanged: isLocalMode
                  ? (value) {
                      final pos = Duration(milliseconds: (value * duration.inMilliseconds).toInt());
                      ref.read(unifiedPlayerControllerProvider.notifier).seek(pos);
                    }
                  : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                _formatDuration(duration),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PlayerControls extends ConsumerWidget {
  final double horizontalPadding;

  const _PlayerControls({this.horizontalPadding = 40});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Watch control states
    final isPlaying = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.isPlaying ?? false));
    final shuffleMode = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.shuffleMode ?? false));
    final loopMode = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.loopMode ?? LoopMode.off));
    final currentSong = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentSong));
    final favoritesAsync = ref.watch(cachedPlaylistSongsProvider(BaseConstants.likePlaylist));
    final isFavorite = currentSong != null && (favoritesAsync.asData?.value.contains(currentSong) ?? false);

    // 计算当前播放模式
    final playMode = _getPlayMode(loopMode, shuffleMode);
    final playModeIcon = _getPlayModeIcon(playMode);
    final playModeTooltip = _getPlayModeTooltip(playMode);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 播放模式按钮（合并了循环和随机）
            IconButton(
              icon: Icon(playModeIcon),
              iconSize: 32,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              onPressed: () {
                ref.read(unifiedPlayerControllerProvider.notifier).togglePlayMode();
              },
              tooltip: playModeTooltip,
            ),

            // 上一首
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 48,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              onPressed: () {
                ref.read(unifiedPlayerControllerProvider.notifier).skipPrevious();
              },
              tooltip: S.previous,
            ),

            // 播放/暂停
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: isDark
                    ? LinearGradient(
                        colors: [AppColors.primary.withValues(alpha: 0.7), AppColors.secondary.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: isDark ? AppColors.primary.withValues(alpha: 0.2) : AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                iconSize: 40,
                onPressed: () {
                  ref.read(unifiedPlayerControllerProvider.notifier).playPause();
                },
                tooltip: isPlaying ? S.pause : S.play,
              ),
            ),

            // 下一首
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 48,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              onPressed: () {
                ref.read(unifiedPlayerControllerProvider.notifier).skipNext();
              },
              tooltip: S.next,
            ),

            // 收藏按钮
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFavorite ? Colors.red : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              iconSize: 32,
              onPressed: currentSong == null
                  ? null
                  : () => FavoriteUtils.toggleFavorite(context, ref, currentSong, isFavorite),
              tooltip: isFavorite ? '取消收藏' : '收藏',
            ),
          ],
        ),
      ),
    );
  }

  /// 获取当前播放模式
  String _getPlayMode(LoopMode loopMode, bool shuffleMode) {
    if (shuffleMode) {
      return '随机播放';
    } else if (loopMode == LoopMode.one) {
      return '单曲循环';
    } else if (loopMode == LoopMode.all) {
      return '全部循环';
    } else {
      return '顺序播放';
    }
  }

  /// 获取播放模式对应的图标
  IconData _getPlayModeIcon(String mode) {
    switch (mode) {
      case '单曲循环':
        return Icons.repeat_one_rounded;
      case '全部循环':
        return Icons.repeat_rounded;
      case '随机播放':
        return Icons.shuffle_rounded;
      default:
        return Icons.playlist_play_rounded;
    }
  }

  /// 获取播放模式对应的提示文本
  String _getPlayModeTooltip(String mode) {
    return mode;
  }
}

class _PlayerActions extends ConsumerStatefulWidget {
  const _PlayerActions();

  @override
  ConsumerState<_PlayerActions> createState() => _PlayerActionsState();
}

class _PlayerActionsState extends ConsumerState<_PlayerActions> with TickerProviderStateMixin {
  int? _currentVolume;
  bool _isLoadingVolume = false;
  bool _isDownloading = false;
  String? _lastVolumeDid;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadVolumeForDid(String did) async {
    if (did.isEmpty) return;
    if (!mounted) return;
    setState(() => _isLoadingVolume = true);
    try {
      final volumeResp = await ref.read(apiClientProvider).getVolume(did);
      if (!mounted) return;
      setState(() {
        _currentVolume = volumeResp.volume;
        _isLoadingVolume = false;
      });
      // 写入缓存：下次进入页面先展示缓存值，避免从 50 跳变
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setInt(SharedPrefKeys.cachedDeviceVolume(did), volumeResp.volume);
    } catch (e) {
      _logger.e("加载远程设备 $did 音量失败: $e");
      if (mounted) {
        setState(() => _isLoadingVolume = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRemote = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.isRemoteMode ?? false));
    final remoteDid = ref.watch(
      unifiedPlayerControllerProvider.select((s) => s.value?.isRemoteMode == true ? s.value?.currentDevice?.did : null),
    );

    // 本地切到远程 / 远程 did 变化：在下一帧触发一次音量拉取（避免在 build 里 setState）
    if (isRemote && remoteDid != null && remoteDid.isNotEmpty && remoteDid != _lastVolumeDid) {
      _lastVolumeDid = remoteDid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // 如果这期间又切走了，避免拉错设备音量
        final latestDid = ref.read(
          unifiedPlayerControllerProvider.select(
            (s) => s.value?.isRemoteMode == true ? s.value?.currentDevice?.did : null,
          ),
        );
        if (latestDid == remoteDid) {
          // 先用缓存值填充 UI（不再默认 50）
          final prefs = ref.read(sharedPreferencesProvider);
          final cached = prefs.getInt(SharedPrefKeys.cachedDeviceVolume(remoteDid));
          if (cached != null && mounted) {
            setState(() => _currentVolume = cached.clamp(0, 100));
          }
          _loadVolumeForDid(remoteDid);
        }
      });
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // 音量控制（仅远程模式显示）
        if (isRemote) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: Row(
              children: [
                // 减小音量按钮
                IconButton(
                  icon: Icon(
                    Icons.volume_down_rounded,
                    size: 24,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  onPressed: _isLoadingVolume ? null : () => _decreaseVolume(ref),
                  tooltip: '减小音量',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                      thumbColor: AppColors.primary,
                    ),
                    child: Slider(
                      value: (_currentVolume ?? 50).toDouble(),
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: '${_currentVolume ?? 50}',
                      onChanged: _isLoadingVolume
                          ? null
                          : (value) {
                              final volume = value.round();
                              setState(() => _currentVolume = volume);
                              ref.read(unifiedPlayerControllerProvider.notifier).setVolume(volume);
                              // 立即缓存，避免下次进页面从 50 跳
                              final did = ref.read(
                                unifiedPlayerControllerProvider.select(
                                  (s) => s.value?.isRemoteMode == true ? s.value?.currentDevice?.did : null,
                                ),
                              );
                              if (did != null && did.isNotEmpty) {
                                final prefs = ref.read(sharedPreferencesProvider);
                                prefs.setInt(SharedPrefKeys.cachedDeviceVolume(did), volume);
                              }
                            },
                    ),
                  ),
                ),
                Text(
                  '${_currentVolume ?? 50}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(width: 12),
                // 增大音量按钮
                IconButton(
                  icon: Icon(
                    Icons.volume_up_rounded,
                    size: 24,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  onPressed: _isLoadingVolume ? null : () => _increaseVolume(ref),
                  tooltip: '增大音量',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        // 操作按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded),
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => const PlayQueueSheet(),
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      transitionAnimationController: AnimationController(
                        vsync: Navigator.of(context),
                        duration: const Duration(milliseconds: 400),
                        reverseDuration: const Duration(milliseconds: 300),
                      ),
                    );
                  },
                  tooltip: S.playQueue,
                ),
                // 定时关机按钮（现在本地和远程模式都支持）
                IconButton(
                  icon: const Icon(Icons.timer_rounded),
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  onPressed: () => _showShutdownDialog(context, ref),
                  tooltip: '定时关机',
                ),
                // 下载按钮
                IconButton(
                  icon: _isDownloading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  onPressed: _isDownloading ? null : () => _downloadCurrentSong(context, ref),
                  tooltip: S.download,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _decreaseVolume(WidgetRef ref) {
    final currentVol = _currentVolume ?? 50;
    final newVolume = (currentVol - 2).clamp(0, 100);
    setState(() => _currentVolume = newVolume);
    ref.read(unifiedPlayerControllerProvider.notifier).setVolume(newVolume);
  }

  void _increaseVolume(WidgetRef ref) {
    final currentVol = _currentVolume ?? 50;
    final newVolume = (currentVol + 2).clamp(0, 100);
    setState(() => _currentVolume = newVolume);
    ref.read(unifiedPlayerControllerProvider.notifier).setVolume(newVolume);
  }

  Future<void> _downloadCurrentSong(BuildContext context, WidgetRef ref) async {
    final state = ref.read(unifiedPlayerControllerProvider).value;
    final currentSong = state?.currentSong;

    if (currentSong == null || currentSong.isEmpty) {
      if (context.mounted) {
        SnackBarUtils.showMessage(context, '当前没有正在播放的歌曲');
      }
      return;
    }

    setState(() => _isDownloading = true);

    try {
      // 获取当前歌曲的 URL
      final apiClient = ref.read(apiClientProvider);
      final musicInfos = await apiClient.getMusicInfos([currentSong], false);

      if (musicInfos.isEmpty || musicInfos.first.url.isEmpty) {
        if (context.mounted) {
          SnackBarUtils.showMessage(context, '无法获取歌曲链接');
        }
        return;
      }

      final musicUrl = musicInfos.first.url;

      // 获取下载目录
      Directory downloadDir;

      if (Platform.isAndroid) {
        // 首先尝试使用公共 Music 目录（需要权限）
        final hasPermission = await PermissionUtils.checkStoragePermission();
        if (hasPermission) {
          try {
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              // 尝试访问公共 Music 目录
              // 获取外部存储根目录（通常是 /storage/emulated/0）
              final externalPath = externalDir.path.split('/Android')[0];
              final publicMusicDir = Directory(path.join(externalPath, 'Music', 'mi_music'));

              // 检查是否可以创建目录（测试权限）
              if (!await publicMusicDir.exists()) {
                try {
                  await publicMusicDir.create(recursive: true);
                  downloadDir = publicMusicDir;
                } catch (e) {
                  _logger.e("创建公共 Music 目录失败: $e");
                  // 权限不足，使用应用特定目录
                  downloadDir = Directory(path.join(externalDir.path, 'Music'));
                }
              } else {
                // 目录已存在，尝试写入测试
                try {
                  final testFile = File(path.join(publicMusicDir.path, '.test'));
                  await testFile.writeAsString('test');
                  await testFile.delete();
                  downloadDir = publicMusicDir;
                } catch (e) {
                  _logger.e("创建公共 Music 目录失败: $e");
                  // 权限不足，使用应用特定目录
                  downloadDir = Directory(path.join(externalDir.path, 'Music'));
                }
              }
            } else {
              // 如果外部存储不可用，使用应用文档目录
              final appDocDir = await getApplicationDocumentsDirectory();
              downloadDir = Directory(path.join(appDocDir.path, 'Music'));
            }
          } catch (e) {
            _logger.e("访问公共目录失败: $e");
            // 如果访问公共目录失败，使用应用特定目录
            try {
              final externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                downloadDir = Directory(path.join(externalDir.path, 'Music'));
              } else {
                final appDocDir = await getApplicationDocumentsDirectory();
                downloadDir = Directory(path.join(appDocDir.path, 'Music'));
              }
            } catch (e2) {
              _logger.e("访问公共目录失败: $e2");
              final appDocDir = await getApplicationDocumentsDirectory();
              downloadDir = Directory(path.join(appDocDir.path, 'Music'));
            }
          }
        } else {
          // 没有权限，请求权限
          final granted = await PermissionUtils.requestStoragePermission();
          if (granted) {
            // 权限已授予，重试访问公共目录
            try {
              final externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                final externalPath = externalDir.path.split('/Android')[0];
                final publicMusicDir = Directory(path.join(externalPath, 'Music', 'mi_music'));
                if (!await publicMusicDir.exists()) {
                  await publicMusicDir.create(recursive: true);
                }
                downloadDir = publicMusicDir;
              } else {
                final appDocDir = await getApplicationDocumentsDirectory();
                downloadDir = Directory(path.join(appDocDir.path, 'Music'));
              }
            } catch (e) {
              _logger.e("访问公共目录失败: $e");
              // 即使有权限也可能失败（Android 10+ 限制），使用应用特定目录
              final externalDir = await getExternalStorageDirectory();
              if (externalDir != null) {
                downloadDir = Directory(path.join(externalDir.path, 'Music'));
              } else {
                final appDocDir = await getApplicationDocumentsDirectory();
                downloadDir = Directory(path.join(appDocDir.path, 'Music'));
              }
            }
          } else {
            // 权限被拒绝，使用应用特定目录
            if (context.mounted) {
              _logger.e("未授予存储权限，文件将保存到应用目录");
              SnackBarUtils.showMessage(context, '未授予存储权限，文件将保存到应用目录', duration: const Duration(seconds: 2));
            }
            final externalDir = await getExternalStorageDirectory();
            if (externalDir != null) {
              downloadDir = Directory(path.join(externalDir.path, 'Music'));
            } else {
              final appDocDir = await getApplicationDocumentsDirectory();
              downloadDir = Directory(path.join(appDocDir.path, 'Music'));
            }
          }
        }
      } else {
        // iOS 或其他平台：使用应用文档目录
        final appDocDir = await getApplicationDocumentsDirectory();
        downloadDir = Directory(path.join(appDocDir.path, 'Music'));
      }

      // 确保目录存在
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // 生成文件名（清理非法字符）
      String safeFileName = currentSong.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(RegExp(r'\s+'), ' ');
      if (!safeFileName.endsWith('.mp3') && !safeFileName.endsWith('.m4a')) {
        safeFileName = '$safeFileName.mp3';
      }

      final filePath = path.join(downloadDir.path, safeFileName);

      // 使用 dio 下载文件
      final dio = ref.read(dioProvider);
      await dio.download(musicUrl, filePath);

      if (context.mounted) {
        SnackBarUtils.showMessage(
          context,
          '${S.downloadSuccess}\n保存位置: $filePath',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      _logger.e("下载歌曲失败: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.downloadFailed}: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _showShutdownDialog(BuildContext context, WidgetRef ref) {
    final defaultOptions = [15, 30, 60, 90, 120]; // 默认选项：15分钟、30分钟、60分钟、90分钟、120分钟

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('定时关机', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ...defaultOptions.map((minutes) {
              return ListTile(
                leading: const Icon(Icons.timer_rounded),
                title: Text('$minutes分钟后关机'),
                onTap: () {
                  ref.read(unifiedPlayerControllerProvider.notifier).sendShutdownCommand(minutes);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已设置$minutes分钟后关机')));
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
