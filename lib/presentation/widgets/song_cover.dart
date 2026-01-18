import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/cache_provider.dart';

/// 歌曲封面组件（支持从缓存获取图片）
class SongCover extends ConsumerWidget {
  final String songName;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const SongCover({
    super.key,
    required this.songName,
    this.size = 48,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 从缓存获取歌曲信息
    final cacheManager = ref.watch(cacheManagerProvider);
    final songInfo = cacheManager.getSongInfo(songName);
    final pictureUrl = songInfo?.pictureUrl;

    // 如果有图片 URL，显示图片
    if (pictureUrl != null && pictureUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: pictureUrl,
          width: size,
          height: size,
          fit: fit,
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightDivider,
              borderRadius: borderRadius ?? BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => _buildDefaultIcon(
            isDark,
            size,
            borderRadius,
          ),
        ),
      );
    }

    // 没有图片，显示默认图标
    return _buildDefaultIcon(isDark, size, borderRadius);
  }

  Widget _buildDefaultIcon(bool isDark, double size, BorderRadius? borderRadius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightDivider,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.music_note,
        color: AppColors.primary,
        size: 24,
      ),
    );
  }
}

