import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/presentation/widgets/song_cover.dart';

/// 播放队列底部抽屉
class PlayQueueSheet extends ConsumerStatefulWidget {
  const PlayQueueSheet({super.key});

  @override
  ConsumerState<PlayQueueSheet> createState() => _PlayQueueSheetState();
}

class _PlayQueueSheetState extends ConsumerState<PlayQueueSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentSong(int currentIndex, int itemCount) {
    if (currentIndex < 0 || currentIndex >= itemCount) return;

    // 等待列表渲染完成后再滚动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // 计算每个列表项的大概高度（ListTile 默认高度约为 56）
      const double itemHeight = 56.0;
      final double targetOffset = currentIndex * itemHeight;

      // 获取可视区域高度
      final double viewportHeight = _scrollController.position.viewportDimension;

      // 计算目标位置，使当前歌曲在可视区域中间
      final double centeredOffset = targetOffset - (viewportHeight / 2) + (itemHeight / 2);

      // 确保滚动位置在有效范围内
      final double maxScroll = _scrollController.position.maxScrollExtent;
      final double clampedOffset = centeredOffset.clamp(0.0, maxScroll);

      _scrollController.animateTo(clampedOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 只监听队列相关字段，避免 position 高频更新导致列表频繁“刷新/重建”
    final hasValue = ref.watch(unifiedPlayerControllerProvider.select((s) => s.hasValue));
    final playlist = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.playlist ?? const []));
    final currentIndex = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentIndex ?? -1));
    final currentSong = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentSong));

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖动指示器
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Text(S.playQueue, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (hasValue)
                  Text(
                    '(${playlist.length})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                const Spacer(),
                // 定位到当前播放歌曲按钮
                if (currentIndex >= 0 && currentIndex < playlist.length)
                  IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: () {
                      _scrollToCurrentSong(currentIndex, playlist.length);
                    },
                    tooltip: '定位到当前播放',
                  ),
                // TextButton.icon(
                //   onPressed: () {
                //     // TODO: 清空队列
                //   },
                //   icon: const Icon(Icons.clear_all),
                //   label: const Text('清空'),
                // ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 播放队列列表
          Expanded(
            child: hasValue
                ? _buildQueueList(context, ref, playlist, currentIndex, currentSong, theme, isDark)
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList(
    BuildContext context,
    WidgetRef ref,
    List<String> playlist,
    int currentIndex,
    String? currentSong,
    ThemeData theme,
    bool isDark,
  ) {
    if (playlist.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music, size: 64, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
            const SizedBox(height: 16),
            Text(
              '播放队列为空',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: playlist.length,
      padding: const EdgeInsets.only(bottom: 16),
      itemExtent: 56.0, // 固定高度优化性能
      physics: const BouncingScrollPhysics(), // 弹性滚动
      itemBuilder: (context, index) {
        final song = playlist[index];
        final isPlaying =
            index == currentIndex ||
            (currentIndex < 0 && currentSong != null && song == currentSong && playlist.indexOf(song) == index);

        return ListTile(
          leading: isPlaying
              ? Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.equalizer, color: Colors.white),
                )
              : SongCover(songName: song, size: 48),
          title: Text(
            song,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isPlaying ? FontWeight.w600 : null,
              color: isPlaying ? AppColors.primary : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // subtitle: const Text('未知艺术家'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPlaying)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.volume_up, size: 20, color: AppColors.primary),
                ),
              // IconButton(
              //   icon: const Icon(Icons.close),
              //   iconSize: 20,
              //   onPressed: () {
              //     // TODO: 从队列移除
              //   },
              //   tooltip: '移除',
              // ),
            ],
          ),
          onTap: () {
            ref.read(unifiedPlayerControllerProvider.notifier).playFromQueueIndex(index);
          },
        );
      },
    );
  }
}
