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
          gradient: const LinearGradient(
            colors: [Colors.redAccent, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          // 统一圆角半径，与默认歌单图标保持一致
          borderRadius: borderRadius ?? BorderRadius.circular(size * 0.22),
          boxShadow: [
            BoxShadow(color: Colors.redAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(Icons.favorite_rounded, color: Colors.white, size: size * 0.5),
      );
    }

    // 系统歌单显示默认图标
    final systemPlaylistNames = {'临时搜索列表', '所有歌曲', '所有电台', '全部', '下载', '其他', '最近新增'};

    if (systemPlaylistNames.contains(playlistName)) {
      return _buildDefaultPlaylistIcon(context);
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
    return _buildDefaultPlaylistIcon(context);
  }

  /// 构建默认歌单图标
  Widget _buildDefaultPlaylistIcon(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 方案 A (流光渐变)：大众审美，现代音乐App主流风格
    // 使用高饱和度的渐变色，营造音乐的律动感和活力
    // 渐变色：从主色调(Indigo)流向强调色(Pink/Purple)
    final gradient = LinearGradient(
      colors: isDark
          ? [AppColors.primaryDark, AppColors.secondaryDark]
          : [AppColors.primaryLight, AppColors.accentLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius ?? BorderRadius.circular(size * 0.22), // 更加圆润的圆角 (Squircle-ish)
        boxShadow: [
          // 添加轻微的投影，增加立体感
          BoxShadow(
            color: (isDark ? AppColors.primary : AppColors.primaryLight).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景装饰纹理 (半透明的大图标)
          Positioned(
            right: -size * 0.2,
            bottom: -size * 0.2,
            child: Icon(Icons.album_rounded, color: Colors.white.withValues(alpha: 0.1), size: size * 0.8),
          ),
          // 中心主图标
          Icon(
            Icons.album_rounded, // 使用唱片图标，最具音乐代表性
            color: Colors.white.withValues(alpha: 0.95), // 纯白图标，在渐变上对比度最好
            size: size * 0.45,
          ),
        ],
      ),
    );
  }
}
