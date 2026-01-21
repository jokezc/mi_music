import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/core/utils/favorite_utils.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';
import 'package:mi_music/presentation/widgets/input_dialog.dart';
import 'package:mi_music/presentation/widgets/playlist_cover.dart';
import 'package:mi_music/presentation/widgets/song_cover.dart';

final _logger = Logger();

/// 歌单详情页面
class PlaylistDetailPage extends ConsumerWidget {
  const PlaylistDetailPage({required this.playlistName, super.key});

  final String playlistName;

  bool _isCustomPlaylist(WidgetRef ref) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用缓存的 provider，优先从缓存获取，缓存不存在时从 API 获取
    final musicsAsync = ref.watch(cachedPlaylistMusicsProvider(playlistName));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final favoritesAsync = ref.watch(cachedPlaylistSongsProvider(BaseConstants.likePlaylist));
    final favoriteSet = favoritesAsync.asData?.value.toSet() ?? <String>{};
    final isCustom = _isCustomPlaylist(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlistName),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // 跳转到搜索界面，指定搜索当前歌单
              context.push('/search?playlist=${Uri.encodeComponent(playlistName)}');
            },
            tooltip: '搜索歌单内容',
          ),
          if (isCustom)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.ac_unit_rounded),
                tooltip: '歌单操作',
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  switch (value) {
                    case 'add_songs':
                      _showAddSongs(context, ref);
                      break;
                    case 'remove_songs':
                      _showRemoveSongs(context, ref);
                      break;
                    case 'rename':
                      _renamePlaylist(context, ref);
                      break;
                    case 'delete':
                      _deletePlaylist(context, ref);
                      break;
                    case 'clear':
                      _clearPlaylist(context, ref);
                      break;
                    case 'play_all':
                      ref.read(unifiedPlayerControllerProvider.notifier).playPlaylistByName(playlistName);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('${S.playing}: $playlistName')));
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'add_songs',
                    child: Row(children: [Icon(Icons.playlist_add), SizedBox(width: 8), Text('添加歌曲')]),
                  ),
                  const PopupMenuItem(
                    value: 'remove_songs',
                    child: Row(children: [Icon(Icons.playlist_remove), SizedBox(width: 8), Text('移除歌曲')]),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('重命名歌单')]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [Icon(Icons.delete), SizedBox(width: 8), Text('删除歌单')]),
                  ),
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(children: [Icon(Icons.cleaning_services), SizedBox(width: 8), Text('清空歌单')]),
                  ),
                  const PopupMenuItem(
                    value: 'play_all',
                    child: Row(children: [Icon(Icons.play_arrow_rounded), SizedBox(width: 8), Text('播放全部')]),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: musicsAsync.when(
        data: (data) {
          final songs = data.musics;
          if (songs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 80, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                  const SizedBox(height: 16),
                  Text(
                    S.emptySongs,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(cacheRefreshControllerProvider.notifier).refresh();
            },
            child: CustomScrollView(
              slivers: [
                // 歌单信息头
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withValues(alpha: 0.1), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        PlaylistCover(playlistName: playlistName, size: 80, borderRadius: BorderRadius.circular(12)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlistName,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${songs.length} 首歌曲',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 歌曲列表
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final song = songs[index];
                      return ListTile(
                        leading: SongCover(songName: song, size: 48),
                        title: Text(song, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                favoriteSet.contains(song) ? Icons.favorite : Icons.favorite_border,
                                color: favoriteSet.contains(song) ? Colors.red : null,
                              ),
                              tooltip: favoriteSet.contains(song) ? '取消收藏' : '收藏',
                              onPressed: () =>
                                  FavoriteUtils.toggleFavorite(context, ref, song, favoriteSet.contains(song)),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              tooltip: '更多',
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteMusic(context, ref, song);
                                } else if (value == 'remove') {
                                  _removeSong(context, ref, song);
                                }
                              },
                              itemBuilder: (context) => [
                                if (isCustom)
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.remove_circle_outline, color: Colors.orange),
                                        SizedBox(width: 8),
                                        Text('从歌单移除'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('永久删除歌曲', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _playSong(context, ref, song),
                      );
                    }, childCount: songs.length),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          // 打印错误信息到控制台
          _logger.e('获取歌单内容错误: $err');
          _logger.e('错误堆栈: $stack');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('${S.error}: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(cacheRefreshControllerProvider.notifier).refresh();
                  },
                  child: const Text(S.retry),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _playSong(BuildContext context, WidgetRef ref, String song) {
    ref.read(unifiedPlayerControllerProvider.notifier).playSong(song, playlistName: playlistName);
  }

  Future<void> _deleteMusic(BuildContext context, WidgetRef ref, String song) async {
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
        await ref.read(apiClientProvider).delMusic(MusicItem(name: song));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除成功')));
          // 刷新当前列表
          ref.read(cacheRefreshControllerProvider.notifier).refreshPlaylistsOnly();
        }
      } catch (e) {
        _logger.e("删除歌曲失败: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }
    }
  }

  Future<void> _showAddSongs(BuildContext context, WidgetRef ref) async {
    try {
      // 1. 获取所有歌曲
      final allSongs = await ref.read(cachedPlaylistSongsProvider('全部').future);
      // 2. 获取当前歌单歌曲
      final currentSongs = await ref.read(cachedPlaylistSongsProvider(playlistName).future);
      // 3. 过滤掉已存在的
      final available = allSongs.where((s) => !currentSongs.contains(s)).toList();

      if (!context.mounted) return;

      final result = await context.push<List<String>>(
        '/song-multi-select',
        extra: {'title': '添加歌曲', 'allSongs': available, 'actionLabel': '添加'},
      );

      if (result != null && result.isNotEmpty) {
        await ref.read(playlistControllerProvider.notifier).addMusicToPlaylist(playlistName, result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已添加 ${result.length} 首歌曲')));
        }
      }
    } catch (e) {
      _logger.e("添加歌曲失败: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
    }
  }

  Future<void> _showRemoveSongs(BuildContext context, WidgetRef ref) async {
    try {
      final currentSongs = await ref.read(cachedPlaylistSongsProvider(playlistName).future);
      if (!context.mounted) return;

      final result = await context.push<List<String>>(
        '/song-multi-select',
        extra: {'title': '移除歌曲', 'allSongs': currentSongs, 'actionLabel': '移除'},
      );

      if (result != null && result.isNotEmpty) {
        await ref.read(playlistControllerProvider.notifier).removeMusicFromPlaylist(playlistName, result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已移除 ${result.length} 首歌曲')));
        }
      }
    } catch (e) {
      _logger.e("移除歌曲失败: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('移除失败: $e')));
      }
    }
  }

  Future<void> _renamePlaylist(BuildContext context, WidgetRef ref) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => InputDialog(title: '重命名歌单', labelText: '新名称', initialValue: playlistName),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != playlistName) {
      final nameToCheck = newName.trim();
      // Check for duplicates
      final playlists = ref.read(playlistUiListProvider).asData?.value ?? [];
      if (playlists.any((p) => p.name == nameToCheck)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('歌单 "$nameToCheck" 已存在，请使用其他名称')));
        }
        return;
      }

      try {
        await ref.read(playlistControllerProvider.notifier).renamePlaylist(playlistName, nameToCheck);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名成功: $newName')));
          // 跳转到新歌单页面 (replace)
          context.pushReplacement('/playlist/${Uri.encodeComponent(newName.trim())}');
        }
      } catch (e) {
        _logger.e("重命名失败: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
        }
      }
    }
  }

  Future<void> _deletePlaylist(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除歌单'),
        content: Text('确定要删除歌单 "$playlistName" 吗？\n(不会删除歌曲文件)'),
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
        await ref.read(playlistControllerProvider.notifier).deletePlaylist(playlistName);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('歌单已删除')));
          Navigator.pop(context); // 返回上一页
        }
      } catch (e) {
        _logger.e("删除歌单失败: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }
    }
  }

  Future<void> _clearPlaylist(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空歌单'),
        content: Text('确定要清空歌单 "$playlistName" 吗？'),
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
        // 调用 updatePlaylistMusic 传空数组
        await ref.read(playlistControllerProvider.notifier).updatePlaylistMusic(playlistName, []);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('歌单已清空')));
        }
      } catch (e) {
        _logger.e("清空歌单失败: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('清空失败: $e')));
        }
      }
    }
  }

  Future<void> _removeSong(BuildContext context, WidgetRef ref, String song) async {
    try {
      await ref.read(playlistControllerProvider.notifier).removeMusicFromPlaylist(playlistName, [song]);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已从歌单移除: $song')));
      }
    } catch (e) {
      _logger.e("移除歌曲失败: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('移除失败: $e')));
      }
    }
  }
}
