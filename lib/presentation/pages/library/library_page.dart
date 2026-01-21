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
import 'package:mi_music/presentation/widgets/device_selector_sheet.dart';
import 'package:mi_music/presentation/widgets/input_dialog.dart';
import 'package:mi_music/presentation/widgets/playlist_cover.dart';
import 'package:mi_music/presentation/widgets/shimmer_loading.dart';

final _logger = Logger();

/// 音乐库页面 - 作为主页
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 当键盘收起时（bottomInset变为0），如果搜索框有焦点，则取消焦点
    final bottomInset = View.of(context).viewInsets.bottom;
    if (bottomInset == 0 && _searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.add),
              tooltip: '歌单操作',
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                switch (value) {
                  case 'create':
                    _showCreatePlaylistDialog(context);
                    break;
                  case 'manage':
                    context.push('/manage-playlists');
                    break;
                  case 'refresh':
                    _handleRefresh();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'create',
                  child: Row(children: [Icon(Icons.playlist_add), SizedBox(width: 8), Text('新建歌单')]),
                ),
                const PopupMenuItem(
                  value: 'manage',
                  child: Row(children: [Icon(Icons.settings), SizedBox(width: 8), Text('管理歌单')]),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(children: [const Icon(Icons.refresh), const SizedBox(width: 8), Text(S.refresh)]),
                ),
              ],
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // 点击空白处取消焦点
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.translucent,
        child: Column(
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

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const InputDialog(title: '新建歌单', labelText: '歌单名称'),
    );

    if (name != null && name.trim().isNotEmpty) {
      try {
        await ref.read(playlistControllerProvider.notifier).createPlaylist(name.trim());
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('歌单 "$name" 创建成功')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    }
  }
}

/// 歌单 Tab
class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用合并了本地状态的 Provider
    final playlistsAsync = ref.watch(playlistUiListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return playlistsAsync.when(
      data: (allPlaylists) {
        // 过滤掉隐藏的歌单
        final visiblePlaylists = allPlaylists.where((p) => !p.isHidden).toList();

        if (visiblePlaylists.isEmpty) {
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
            padding: const EdgeInsets.symmetric(vertical: 4), // 减小列表上下间距
            itemCount: visiblePlaylists.length,
            itemBuilder: (context, index) {
              return _PlaylistTile(playlist: visiblePlaylists[index]);
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

class _PlaylistTile extends ConsumerWidget {
  final PlaylistUiModel playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = playlist.name;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final songsAsync = ref.watch(cachedPlaylistSongsProvider(name));
    final count = songsAsync.asData?.value.length ?? 0;

    return ListTile(
      visualDensity: const VisualDensity(vertical: -2), // 减小垂直间距
      leading: PlaylistCover(playlistName: name, size: 48),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$count 首',
        style: theme.textTheme.bodySmall?.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            color: AppColors.primary,
            onPressed: () {
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
