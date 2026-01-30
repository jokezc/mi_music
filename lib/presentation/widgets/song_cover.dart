import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/cache_provider.dart';

/// 歌曲封面组件（支持从缓存获取图片）
class SongCover extends ConsumerWidget {
  final String songName;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const SongCover({super.key, required this.songName, this.size = 48, this.borderRadius, this.fit = BoxFit.cover});

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
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => _buildDefaultIcon(isDark, size, borderRadius),
        ),
      );
    }

    // 没有图片，显示默认图标
    return _buildDefaultIcon(isDark, size, borderRadius);
  }

  Widget _buildDefaultIcon(bool isDark, double size, BorderRadius? borderRadius) {
    // 方案 B (微渐变 - 质感增强版)：
    // 解决之前版本在浅色模式下过于"隐形"的问题，增加实体感
    // 使用浅蓝紫渐变，既保持清新，又有足够的对比度

    final bgColors = isDark
        ? [AppColors.primary.withValues(alpha: 0.3), AppColors.primary.withValues(alpha: 0.15)]
        : [AppColors.primaryLight.withValues(alpha: 0.25), AppColors.primaryLight.withValues(alpha: 0.1)];

    final iconColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: borderRadius ?? BorderRadius.circular(size * 0.2),
        // 添加轻微边框，防止背景过淡时边界模糊
        border: Border.all(color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.08), width: 1),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: iconColor, // 恢复不透明度，增加清晰度
          size: size * 0.5,
        ),
      ),
    );
  }
}
