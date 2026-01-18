import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';

final _logger = Logger();

/// 收藏工具类
class FavoriteUtils {
  FavoriteUtils._();

  /// 切换收藏状态
  ///
  /// [context] 用于显示错误消息
  /// [ref] Riverpod 的 WidgetRef
  /// [song] 歌曲名称
  /// [isFavorite] 当前是否为收藏状态
  static Future<void> toggleFavorite(BuildContext context, WidgetRef ref, String? song, bool isFavorite) async {
    if (song == null) {
      return;
    }
    try {
      final controller = ref.read(playlistControllerProvider.notifier);
      if (isFavorite) {
        await controller.removeMusicFromPlaylist(BaseConstants.likePlaylist, [song]);
      } else {
        await controller.addMusicToPlaylist(BaseConstants.likePlaylist, [song]);
      }
      // 刷新收藏歌单
      await ref
          .read(cacheRefreshControllerProvider.notifier)
          .refreshPlaylistsOnly(playlistName: BaseConstants.likePlaylist);
    } catch (e) {
      _logger.e("切换收藏状态失败: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }
}
