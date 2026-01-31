import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';
import 'package:mi_music/data/providers/settings_provider.dart';
import 'package:mi_music/presentation/widgets/device_selector_sheet.dart';
import 'package:mi_music/presentation/widgets/input_dialog.dart';
import 'package:mi_music/presentation/widgets/playlist_cover.dart';
import 'package:mi_music/presentation/widgets/quick_device_switcher.dart';
import 'package:mi_music/presentation/widgets/shimmer_loading.dart';

final _logger = Logger();

/// 音乐库页面 - 作为主页
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _deviceSwitcherKey = GlobalKey<QuickDeviceSwitcherState>(); // 用于调用 QuickDeviceSwitcher 的 refreshStatus

  @override
  void initState() {
    super.initState();
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
              icon: const Icon(Icons.ac_unit_rounded),
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
                  child: Row(children: [Icon(Icons.playlist_add_rounded), SizedBox(width: 8), Text(S.createPlaylist)]),
                ),
                const PopupMenuItem(
                  value: 'manage',
                  child: Row(children: [Icon(Icons.settings_rounded), SizedBox(width: 8), Text(S.managePlaylists)]),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(children: [Icon(Icons.refresh_rounded), SizedBox(width: 8), Text(S.refreshPlaylists)]),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 首页搜索框 - 点击直接跳转搜索页
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GestureDetector(
              onTap: () {
                // 跳转到搜索界面，指定搜索全部歌单
                context.push('/search?playlist=${Uri.encodeComponent('全部')}');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface, // 类似输入框的背景色
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors
                                .lightTextSecondary, // Input decoration prefixIcon default is usually text secondary or hint
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '搜索全部歌单中的歌曲...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint, // Hint text color
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 快速设备切换栏 - 固定模式
          if (ref.watch(settingsProvider.select((s) => s.showQuickDeviceSwitcher && s.pinQuickDeviceSwitcher)))
            QuickDeviceSwitcher(key: _deviceSwitcherKey),
          Expanded(
            child: _PlaylistsTab(
              header: ref.watch(settingsProvider.select((s) => s.showQuickDeviceSwitcher && !s.pinQuickDeviceSwitcher))
                  ? QuickDeviceSwitcher(key: _deviceSwitcherKey)
                  : null,
            ),
          ),
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

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const InputDialog(title: '新建歌单', labelText: '歌单名称'),
    );

    if (name != null && name.trim().isNotEmpty) {
      final nameToCheck = name.trim();
      // Check for duplicates
      final playlists = ref.read(playlistUiListProvider).asData?.value ?? [];
      if (playlists.any((p) => p.name == nameToCheck)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('歌单 "$nameToCheck" 已存在，请使用其他名称')));
        return;
      }

      try {
        await ref.read(playlistControllerProvider.notifier).createPlaylist(nameToCheck);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('歌单 "$nameToCheck" 创建成功')));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    }
  }
}

/// 歌单 Tab
class _PlaylistsTab extends ConsumerWidget {
  final Widget? header;
  const _PlaylistsTab({this.header});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用合并了本地状态的 Provider
    final playlistsAsync = ref.watch(playlistUiListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return playlistsAsync.when(
      skipLoadingOnRefresh: true,
      data: (allPlaylists) {
        // 过滤掉隐藏的歌单
        final visiblePlaylists = allPlaylists.where((p) => !p.isHidden).toList();

        if (visiblePlaylists.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(cacheRefreshControllerProvider.notifier).refresh();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7, // 确保有足够高度触发下拉刷新
                child: Column(
                  children: [
                    if (header != null) header!,
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            size: 80,
                            color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            S.emptyPlaylist,
                            style: theme.textTheme.bodyLarge?.copyWith(
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
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // 下拉刷新也使用统一的刷新逻辑
            await ref.read(cacheRefreshControllerProvider.notifier).refresh();
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4), // 减小列表上下间距
            itemCount: visiblePlaylists.length + (header != null ? 1 : 0),
            itemBuilder: (context, index) {
              if (header != null) {
                if (index == 0) return header!;
                return _PlaylistTile(playlist: visiblePlaylists[index - 1]);
              }
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
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
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
            icon: const Icon(Icons.play_circle_outline_rounded),
            color: AppColors.primary,
            onPressed: () {
              ref.read(unifiedPlayerControllerProvider.notifier).playPlaylistByName(name);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.playing}: $name')));
            },
            tooltip: S.play,
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () {
        context.push('/playlist/${Uri.encodeComponent(name)}');
      },
    );
  }
}
