import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/presentation/widgets/song_cover.dart';

/// 底部迷你播放条
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 仅监听需要的字段，避免 position 高频更新导致整条迷你栏整体重建产生闪烁
    // 使用 select 监听 hasValue，替代直接 watch provider 导致的频繁重绘
    final hasValue = ref.watch(unifiedPlayerControllerProvider.select((s) => s.hasValue));

    if (!hasValue) return const SizedBox.shrink();

    final currentSong = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentSong));
    final isPlaying = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.isPlaying ?? false));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push('/player');
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border(top: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.lightDivider, width: 1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条 (提取为单独组件以避免父组件重绘)
              const _MiniPlayerProgressBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // 音乐图标/封面
                      Hero(
                        tag: 'player_cover',
                        child: currentSong != null && currentSong.isNotEmpty
                            ? SongCover(songName: currentSong, size: 44)
                            : Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.music_note, color: Colors.white, size: 24),
                              ),
                      ),
                      const SizedBox(width: 12),
                      // 歌曲信息
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentSong ?? S.notPlaying,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // 只有在远程模式下显示设备名，或者播放列表
                            /*
                          if (state.config.isRemoteMode)
                            Text(
                              state.config.currentDevice?.name ?? '未知设备',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            */
                          ],
                        ),
                      ),
                      // 播放控制按钮
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded),
                            iconSize: 28,
                            onPressed: () {
                              ref.read(unifiedPlayerControllerProvider.notifier).skipPrevious();
                            },
                            tooltip: S.previous,
                          ),
                          IconButton(
                            icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                            iconSize: 40,
                            color: AppColors.primary,
                            onPressed: () {
                              // 避免快速点击闪烁，加个简单的防抖或状态判断
                              // 但通常闪烁是因为 state 更新有延迟。
                              // 这里主要是 isPlaying 状态的快速变化。
                              // 可以不做特别处理，如果播放器状态流是准确的。
                              ref.read(unifiedPlayerControllerProvider.notifier).playPause();
                            },
                            tooltip: isPlaying ? S.pause : S.play,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded),
                            iconSize: 28,
                            onPressed: () {
                              ref.read(unifiedPlayerControllerProvider.notifier).skipNext();
                            },
                            tooltip: S.next,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 独立进度条组件，只监听进度和时长变化，避免导致整个 MiniPlayer 重绘
class _MiniPlayerProgressBar extends ConsumerWidget {
  const _MiniPlayerProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.position ?? Duration.zero));
    final duration = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.duration ?? Duration.zero));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LinearProgressIndicator(
      value: duration.inMilliseconds > 0 ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0) : 0.0,
      backgroundColor: isDark ? AppColors.darkDivider : AppColors.lightDivider,
      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      minHeight: 2,
    );
  }
}
