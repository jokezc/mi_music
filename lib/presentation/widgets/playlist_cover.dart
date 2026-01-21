import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/presentation/widgets/song_cover.dart';

/// 歌单封面组件
/// - 收藏歌单：显示爱心图标
/// - 用户歌单：显示第一首歌曲的封面，如果没有封面则显示默认图标
/// - 系统歌单：显示默认图标
class PlaylistCover extends ConsumerWidget {
  final String playlistName;
  final double size;
  final BorderRadius? borderRadius;

  const PlaylistCover({super.key, required this.playlistName, this.size = 48, this.borderRadius});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 收藏歌单显示爱心图标
    if (playlistName == BaseConstants.likePlaylist) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
      );
    }

    // 系统歌单显示默认图标
    final systemPlaylistNames = {'临时搜索列表', '所有歌曲', '所有电台', '全部', '下载', '其他', '最近新增'};

    if (systemPlaylistNames.contains(playlistName)) {
      return _buildDefaultPlaylistIcon();
    }

    // 用户歌单：尝试获取第一首歌曲的封面
    final cacheManager = ref.watch(cacheManagerProvider);
    final playlist = cacheManager.getPlaylist(playlistName);

    if (playlist != null && playlist.songs.isNotEmpty) {
      final firstSong = playlist.songs.first;
      // 检查第一首歌曲是否有封面
      final songInfo = cacheManager.getSongInfo(firstSong);
      final pictureUrl = songInfo?.pictureUrl;

      // 如果有封面，使用 SongCover 组件显示
      if (pictureUrl != null && pictureUrl.isNotEmpty) {
        return SongCover(songName: firstSong, size: size, borderRadius: borderRadius);
      }
    }

    // 没有歌曲或获取失败，显示默认图标
    return _buildDefaultPlaylistIcon();
  }

  /// 构建默认歌单图标
  Widget _buildDefaultPlaylistIcon() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: const Icon(Icons.playlist_play_rounded, color: Colors.white, size: 24),
    );
  }
}
