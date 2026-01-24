import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/utils/snackbar_utils.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';

final _logger = Logger();

class SongUtils {
  SongUtils._();

  /// 判断是否为自定义歌单
  static bool isCustomPlaylist(WidgetRef ref, String playlistName) {
    if (playlistName.isEmpty) return false;
    // 收藏歌单也是自定义歌单（可编辑）
    if (playlistName == BaseConstants.likePlaylist) return true;

    // 优先通过 PlaylistUiModel 判断类型，更准确
    final playlists = ref.read(playlistUiListProvider).asData?.value ?? [];
    try {
      final playlist = playlists.firstWhere((p) => p.name == playlistName);
      return playlist.type == PlaylistType.custom;
    } catch (_) {
      // 降级使用名称判断
      return !BaseConstants.systemPlaylistNames.contains(playlistName);
    }
  }

  /// 处理当前播放的歌曲（如果是当前播放，则切换下一首）
  static Future<void> _handlePlayingSong(WidgetRef ref, String song) async {
    final playerState = ref.read(unifiedPlayerControllerProvider).value;
    final currentSong = playerState?.currentSong;

    if (currentSong == song) {
      final playlist = playerState?.playlist ?? [];
      if (playlist.length > 1) {
        await ref.read(unifiedPlayerControllerProvider.notifier).skipNext();
        // 等待一点时间让状态更新
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        // 如果是最后一首，尝试暂停（目前没有直接停止接口，先不做额外处理，API删除后播放器自然会报错或停止）
      }
    }
  }

  /// 删除歌曲
  static Future<void> deleteSong(BuildContext context, WidgetRef ref, String song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除歌曲'),
        content: Text('确定要永久删除 "$song" 吗？\n此操作将从所有歌单中移除该歌曲文件。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(S.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _handlePlayingSong(ref, song);

        await ref.read(apiClientProvider).delMusic(MusicItem(name: song));

        if (context.mounted) {
          SnackBarUtils.showSuccess(context, '删除成功');
          // 刷新数据
          ref.read(cacheRefreshControllerProvider.notifier).refresh();
          // 刷新播放器当前歌单（如果正好是当前歌单）
          ref.read(unifiedPlayerControllerProvider.notifier).refreshCurrentPlaylist();
        }
      } catch (e) {
        _logger.e('删除歌曲失败: $e');
        if (context.mounted) {
          SnackBarUtils.showError(context, '删除失败: $e');
        }
      }
    }
  }

  /// 从歌单移除歌曲
  static Future<void> removeSongFromPlaylist(
    BuildContext context,
    WidgetRef ref,
    String song,
    String playlistName,
  ) async {
    // 移除歌曲一般不需要确认，或者可以加一个简单的撤销（这里先直接移除）
    try {
      await _handlePlayingSong(ref, song);

      await ref.read(playlistControllerProvider.notifier).removeMusicFromPlaylist(playlistName, [song]);

      if (context.mounted) {
        SnackBarUtils.showInfo(context, '已从歌单移除: $song');
        // 刷新播放器当前歌单
        ref.read(unifiedPlayerControllerProvider.notifier).refreshCurrentPlaylist();
      }
    } catch (e) {
      _logger.e('移除歌曲失败: $e');
      if (context.mounted) {
        SnackBarUtils.showError(context, '移除失败: $e');
      }
    }
  }
}
