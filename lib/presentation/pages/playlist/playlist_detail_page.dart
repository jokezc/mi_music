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
import 'package:mi_music/presentation/widgets/playlist_cover.dart';
import 'package:mi_music/presentation/widgets/song_cover.dart';

final _logger = Logger();

/// 歌单详情页面
class PlaylistDetailPage extends ConsumerWidget {
  const PlaylistDetailPage({required this.playlistName, super.key});

  final String playlistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用缓存的 provider，优先从缓存获取，缓存不存在时从 API 获取
    final musicsAsync = ref.watch(cachedPlaylistMusicsProvider(playlistName));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final favoritesAsync = ref.watch(cachedPlaylistSongsProvider(BaseConstants.likePlaylist));
    final favoriteSet = favoritesAsync.asData?.value.toSet() ?? <String>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(playlistName),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_filled),
            color: AppColors.primary,
            onPressed: () {
              // 使用 playMusicList API 播放整个歌单
              ref.read(unifiedPlayerControllerProvider.notifier).playPlaylistByName(playlistName);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.playing}: $playlistName')));
            },
            tooltip: '播放全部',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // 跳转到搜索界面，指定搜索当前歌单
              context.push('/search?playlist=${Uri.encodeComponent(playlistName)}');
            },
            tooltip: '搜索歌单内容',
          ),
          /*IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // 使用统一的刷新控制器
              try {
                await ref.read(cacheRefreshControllerProvider.notifier).refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('刷新成功！')));
                }
              } catch (e) {
                _logger.e("刷新歌单失败: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刷新失败: $e')));
                }
              }
            },
            tooltip: S.refresh,
          ),*/
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
                              Text(
                                '${songs.length} 首歌曲',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
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
                                }
                              },
                              itemBuilder: (context) => [
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
          ref.read(cacheRefreshControllerProvider.notifier).refresh();
        }
      } catch (e) {
        _logger.e("删除歌曲失败: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }
    }
  }
}
