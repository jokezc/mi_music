import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/utils/snackbar_utils.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';
import 'package:mi_music/presentation/widgets/input_dialog.dart';
import 'package:mi_music/presentation/widgets/playlist_cover.dart';

class AddToPlaylistSheet extends ConsumerWidget {
  final String song;

  const AddToPlaylistSheet({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 使用 playlistNamesProvider 直接获取自定义歌单列表，避免使用 UiListProvider 的过滤逻辑
    // 返回的是 Future<PlaylistNamesResp>
    final playlistsAsync = ref.watch(playlistNamesProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('添加到歌单', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const Divider(),

          // List
          Expanded(
            child: playlistsAsync.when(
              skipLoadingOnRefresh: true,
              data: (resp) {
                // Manually construct the list: Like playlist + Custom playlists
                final customNames = resp.names.where((name) => name != BaseConstants.likePlaylist).toList();

                // Sort custom playlists by name
                customNames.sort();

                // Combine: Like playlist is always first
                final allPlaylists = [BaseConstants.likePlaylist, ...customNames];

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: allPlaylists.length + 1, // +1 for "Create New"
                  itemBuilder: (context, index) {
                    // 0 is "Create New"
                    if (index == 0) {
                      return ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_rounded, size: 28),
                        ),
                        title: const Text('新建歌单'),
                        onTap: () => _showCreatePlaylistDialog(context, ref),
                      );
                    }

                    final playlistName = allPlaylists[index - 1];
                    return _PlaylistItem(playlistName: playlistName, song: song);
                  },
                );
              },
              error: (err, stack) => Center(child: Text('加载失败: $err')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const InputDialog(title: '新建歌单', labelText: '歌单名称', confirmText: '创建并添加'),
    );

    if (name != null && name.isNotEmpty) {
      if (!context.mounted) return;
      try {
        // 1. Create playlist
        await ref.read(playlistControllerProvider.notifier).createPlaylist(name);

        // 2. Add song to it
        await ref.read(playlistControllerProvider.notifier).addMusicToPlaylist(name, [song]);

        if (context.mounted) {
          SnackBarUtils.showSuccess(context, '已创建歌单 "$name" 并添加歌曲');
          Navigator.pop(context); // Close the sheet
        }
      } catch (e) {
        if (context.mounted) {
          SnackBarUtils.showError(context, '操作失败: $e');
        }
      }
    }
  }
}

class _PlaylistItem extends ConsumerWidget {
  final String playlistName;
  final String song;

  const _PlaylistItem({required this.playlistName, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch songs in this playlist to check if already added
    // Note: cachedPlaylistSongsProvider returns Future, so we use .future
    // But since it's an async provider, we should use when/watch properly.
    // However, cachedPlaylistSongsProvider is defined as FutureProvider.
    // Let's check cache_provider.dart again.
    // It is: @Riverpod(keepAlive: true) Future<List<String>> cachedPlaylistSongs(...)

    final songsAsync = ref.watch(cachedPlaylistSongsProvider(playlistName));

    final theme = Theme.of(context);

    return songsAsync.when(
      data: (songs) {
        final isAdded = songs.contains(song);

        return ListTile(
          leading: PlaylistCover(
            playlistName: playlistName,
            size: 48,
          ), // Use playlistName not displayName for proper detection
          title: Text(playlistName, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${songs.length} 首歌曲'),
          trailing: isAdded
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: theme.disabledColor),
                    const SizedBox(width: 4),
                    Text('已添加', style: theme.textTheme.bodySmall?.copyWith(color: theme.disabledColor)),
                  ],
                )
              : null,
          onTap: isAdded
              ? null
              : () async {
                  try {
                    await ref.read(playlistControllerProvider.notifier).addMusicToPlaylist(playlistName, [song]);
                    if (context.mounted) {
                      SnackBarUtils.showSuccess(context, '已添加到 "$playlistName"');
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      SnackBarUtils.showError(context, '添加失败: $e');
                    }
                  }
                },
        );
      },
      loading: () => ListTile(
        leading: const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator())),
        title: Text(playlistName),
      ),
      error: (err, stack) =>
          ListTile(leading: const Icon(Icons.error_outline), title: Text(playlistName), subtitle: const Text('获取失败')),
    );
  }
}
