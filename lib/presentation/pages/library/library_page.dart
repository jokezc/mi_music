import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';
import 'package:mi_music/data/providers/system_provider.dart';
import 'package:mi_music/presentation/widgets/device_selector_sheet.dart';
import 'package:mi_music/presentation/widgets/playlist_cover.dart';
import 'package:mi_music/presentation/widgets/shimmer_loading.dart';

final _logger = Logger();

/// 音乐库页面 - 作为主页
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (!mounted) return;
    try {
      await ref.read(cacheRefreshControllerProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('刷新成功！')));
    } catch (e) {
      _logger.e("刷新缓存失败: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('刷新失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLocalMode = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.isLocalMode ?? true));

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.appName),
        actions: [
          IconButton(
            icon: Icon(
              isLocalMode ? Icons.smartphone_rounded : Icons.speaker_rounded,
              color: !isLocalMode
                  ? AppColors.primary
                  : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
            ),
            onPressed: () => _showDeviceSelector(context),
            tooltip: S.deviceSelector,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _handleRefresh, tooltip: S.refresh),
        ],
      ),
      body: Column(
        children: [
          // 首页搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜索全部歌单中的歌曲...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
                contentPadding: EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  final query = val.trim();
                  _searchController.clear();
                  // 跳转到搜索界面，指定搜索全部歌单，并带上搜索词
                  context.push('/search?playlist=${Uri.encodeComponent('全部')}&q=${Uri.encodeComponent(query)}');
                }
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          const Expanded(child: _PlaylistsTab()),
        ],
      ),
    );
  }

  Future<void> _showDeviceSelector(BuildContext context) async {
    try {
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => const DeviceSelectorSheet(),
      );
    } catch (e) {
      // 如果显示底部表单失败，显示错误提示
      _logger.e("显示设备选择器失败: $e");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('打开设备选择器失败: $e')));
    }
  }
}

/// 歌单 Tab
class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  /// 系统级别的歌单名称列表（不包括"收藏"，因为收藏需要置顶）
  static const _systemPlaylistNames = {'临时搜索列表', '所有歌曲', '所有电台', '全部', '下载', '其他', '最近新增'};

  /// 对歌单列表进行排序：
  /// 1. "收藏" 置顶
  /// 2. 用户创建的歌单（非系统歌单）排在前面
  /// 3. 系统歌单（除了"收藏"）排在最后
  List<String> _sortPlaylists(List<String> names) {
    final favoritePlaylist = <String>[];
    final userPlaylists = <String>[];
    final systemPlaylists = <String>[];

    for (final name in names) {
      if (name == BaseConstants.likePlaylist) {
        favoritePlaylist.add(name);
      } else if (_systemPlaylistNames.contains(name)) {
        systemPlaylists.add(name);
      } else {
        userPlaylists.add(name);
      }
    }

    // 对用户歌单和系统歌单进行字母排序
    userPlaylists.sort();
    systemPlaylists.sort();

    // 合并：收藏 -> 用户歌单 -> 系统歌单
    return [...favoritePlaylist, ...userPlaylists, ...systemPlaylists];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 优先使用缓存
    final playlistsAsync = ref.watch(cachedPlaylistNamesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return playlistsAsync.when(
      data: (names) {
        // 对歌单进行排序：收藏置顶，用户歌单优先，系统歌单排在最下
        final visibleNames = _sortPlaylists(names);

        if (visibleNames.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.queue_music, size: 80, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                const SizedBox(height: 16),
                Text(
                  S.emptyPlaylist,
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
            // 下拉刷新也使用统一的刷新逻辑
            await ref.read(cacheRefreshControllerProvider.notifier).refresh();
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: visibleNames.length,
            itemBuilder: (context, index) {
              final name = visibleNames[index];
              return ListTile(
                leading: PlaylistCover(playlistName: name, size: 48),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline),
                      color: AppColors.primary,
                      onPressed: () {
                        // 播放整个歌单
                        ref.read(unifiedPlayerControllerProvider.notifier).playPlaylistByName(name);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.playing}: $name')));
                      },
                      tooltip: S.play,
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  context.push('/playlist/${Uri.encodeComponent(name)}');
                },
              );
            },
          ),
        );
      },
      loading: () => ListShimmer(itemBuilder: () => const PlaylistItemShimmer()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('${S.error}: $err'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(cacheRefreshControllerProvider.notifier).refresh(),
              child: const Text(S.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// 所有歌曲 Tab
class _AllSongsTab extends ConsumerStatefulWidget {
  const _AllSongsTab();

  @override
  ConsumerState<_AllSongsTab> createState() => _AllSongsTabState();
}

class _AllSongsTabState extends ConsumerState<_AllSongsTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final favoritesAsync = ref.watch(cachedPlaylistSongsProvider(BaseConstants.likePlaylist));
    final favoriteSet = favoritesAsync.asData?.value.toSet() ?? <String>{};

    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: S.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (val) {
              setState(() => _query = val);
            },
          ),
        ),
        // 歌曲列表
        Expanded(
          child: ref
              .watch(cachedPlaylistMusicsProvider('全部'))
              .when(
                data: (data) {
                  // 所有歌曲 Tab 固定展示「全部」歌单内容
                  final songs = data.musics;

                  final filteredSongs = _query.isEmpty
                      ? songs
                      : songs.where((s) => s.toLowerCase().contains(_query.toLowerCase())).toList();

                  if (filteredSongs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_off,
                            size: 80,
                            color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                          ),
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
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filteredSongs.length,
                      itemBuilder: (context, index) {
                        final song = filteredSongs[index];
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.lightDivider,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.music_note, color: AppColors.primary),
                          ),
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
                                onPressed: () => _toggleFavorite(context, song, isFavorite: favoriteSet.contains(song)),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                tooltip: '更多',
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteMusic(context, song);
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
                          onTap: () => _playSong(song, listname: '全部'),
                        );
                      },
                    ),
                  );
                },
                loading: () => ListShimmer(itemBuilder: () => const SongItemShimmer()),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('${S.error}: $err'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(cacheRefreshControllerProvider.notifier).refresh(),
                        child: const Text(S.retry),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }

  void _playSong(String song, {String? listname}) {
    ref.read(unifiedPlayerControllerProvider.notifier).playSong(song, playlistName: listname);
  }

  Future<void> _toggleFavorite(BuildContext context, String song, {required bool isFavorite}) async {
    try {
      final controller = ref.read(playlistControllerProvider.notifier);
      if (isFavorite) {
        await controller.removeMusicFromPlaylist(BaseConstants.likePlaylist, [song]);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消收藏')));
      } else {
        await controller.addMusicToPlaylist(BaseConstants.likePlaylist, [song]);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已收藏')));
      }
      await ref.read(cacheRefreshControllerProvider.notifier).refresh();
    } catch (e) {
      _logger.e('toggleFavorite 收藏失败: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  Future<void> _deleteMusic(BuildContext context, String song) async {
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
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除成功')));
        // 刷新列表
        ref.read(cacheRefreshControllerProvider.notifier).refresh();
      } catch (e) {
        _logger.e("删除歌单失败: $e");
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }
}

/// 收藏 Tab (暂时显示占位内容，后续可扩展)
// ignore: unused_element
class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 尝试获取 "收藏" 歌单的内容（使用缓存）
    final favoritesAsync = ref.watch(cachedPlaylistMusicsProvider(BaseConstants.likePlaylist));

    return favoritesAsync.when(
      data: (data) {
        final songs = data.musics;
        if (songs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 80, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                const SizedBox(height: 16),
                Text(
                  '暂无收藏歌曲',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '可以将喜欢的歌曲添加到"收藏"歌单',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
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
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.accentLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white),
                ),
                title: Text(song, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite),
                  color: Colors.red,
                  tooltip: '取消收藏',
                  onPressed: () async {
                    try {
                      await ref.read(playlistControllerProvider.notifier).removeMusicFromPlaylist(
                        BaseConstants.likePlaylist,
                        [song],
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已取消收藏')));
                      await ref.read(cacheRefreshControllerProvider.notifier).refresh();
                    } catch (e) {
                      _logger.e("收藏/取消收藏操作失败: $e");
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                    }
                  },
                ),
                onTap: () {
                  ref
                      .read(unifiedPlayerControllerProvider.notifier)
                      .playSong(song, playlistName: BaseConstants.likePlaylist);
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) {
        // 如果没有"收藏"歌单，显示空状态
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border, size: 80, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
              const SizedBox(height: 16),
              Text(
                '暂无收藏歌曲',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '创建一个名为"收藏"的歌单来使用此功能',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
