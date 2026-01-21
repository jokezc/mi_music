import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mi_music/core/theme/app_colors.dart';

/// 通用歌曲列表项组件
class SongTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final VoidCallback? onAddToPlaylist;
  final bool isFavorite;
  final bool showSlideActions;
  final Widget? leading;

  const SongTile({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.onPlay,
    this.onFavorite,
    this.onDelete,
    this.onAddToPlaylist,
    this.isFavorite = false,
    this.showSlideActions = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tile = ListTile(
      leading:
          leading ??
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightDivider,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.music_note_rounded, color: AppColors.primary),
          ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle != null
          ? Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: onPlay != null
          ? IconButton(
              icon: const Icon(Icons.play_circle_rounded),
              color: AppColors.primary,
              onPressed: onPlay,
              tooltip: '播放',
            )
          : null,
      onTap: onTap,
    );

    if (!showSlideActions) {
      return tile;
    }

    return Slidable(
      key: ValueKey(title),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          if (onFavorite != null)
            SlidableAction(
              onPressed: (_) => onFavorite?.call(),
              backgroundColor: isFavorite
                  ? AppColors.warning
                  : AppColors.accent,
              foregroundColor: Colors.white,
              icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: isFavorite ? '取消收藏' : '收藏',
            ),
          if (onAddToPlaylist != null)
            SlidableAction(
              onPressed: (_) => onAddToPlaylist?.call(),
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
              icon: Icons.playlist_add_rounded,
              label: '添加到歌单',
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: '删除',
            ),
        ],
      ),
      child: tile,
    );
  }
}

/// 歌单列表项组件
class PlaylistTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int? songCount;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool showSlideActions;

  const PlaylistTile({
    super.key,
    required this.title,
    this.subtitle,
    this.songCount,
    this.onTap,
    this.onPlay,
    this.onDelete,
    this.onEdit,
    this.showSlideActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleText = songCount != null
        ? '${songCount!} 首歌曲'
        : subtitle ?? '';

    final tile = ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.playlist_play_rounded, color: Colors.white),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitleText.isNotEmpty
          ? Text(subtitleText, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPlay != null)
            IconButton(
              icon: const Icon(Icons.play_circle_rounded),
              color: AppColors.primary,
              onPressed: onPlay,
              tooltip: '播放',
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );

    if (!showSlideActions) {
      return tile;
    }

    return Slidable(
      key: ValueKey(title),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          if (onEdit != null)
            SlidableAction(
              onPressed: (_) => onEdit?.call(),
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: '编辑',
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: '删除',
            ),
        ],
      ),
      child: tile,
    );
  }
}
