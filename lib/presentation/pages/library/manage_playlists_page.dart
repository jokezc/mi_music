import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';
import 'package:mi_music/presentation/widgets/input_dialog.dart';

class ManagePlaylistsPage extends ConsumerStatefulWidget {
  const ManagePlaylistsPage({super.key});

  @override
  ConsumerState<ManagePlaylistsPage> createState() => _ManagePlaylistsPageState();
}

class _ManagePlaylistsPageState extends ConsumerState<ManagePlaylistsPage> {
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};

  @override
  Widget build(BuildContext context) {
    final playlistAsync = ref.watch(playlistUiListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '已选择 ${_selectedItems.length} 项' : '管理歌单'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedItems.clear();
                  });
                },
              )
            : const BackButton(),
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: '批量管理',
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                });
              },
            ),
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.visibility_off),
              tooltip: '批量隐藏',
              onPressed: _selectedItems.isEmpty ? null : () => _batchHide(true),
            ),
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: '批量显示',
              onPressed: _selectedItems.isEmpty ? null : () => _batchHide(false),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '批量删除',
              onPressed: _selectedItems.isEmpty ? null : _batchDelete,
            ),
          ],
        ],
      ),
      body: playlistAsync.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return const Center(child: Text('暂无歌单'));
          }
          return _buildList(playlists);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildList(List<PlaylistUiModel> playlists) {
    // ReorderableListView doesn't support easy mixing of reorderable and non-reorderable items with index stability issues in some versions,
    // but we can try to use a proxy list.
    // Actually, simply using ReorderableListView with onReorder is fine.
    // If we want to disable dragging for Favorites, we just don't wrap it in a drag listener or ignore the move.

    return ReorderableListView.builder(
      itemCount: playlists.length,
      onReorder: (oldIndex, newIndex) => _onReorder(playlists, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) {
        // 自定义拖拽时的样式，保持背景透明，只保留阴影效果
        return Material(color: Colors.transparent, child: child);
      },
      itemBuilder: (context, index) {
        final item = playlists[index];
        final isSelected = _selectedItems.contains(item.name);
        final isFavorite = item.name == BaseConstants.likePlaylist;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          key: ValueKey(item.name),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), // 修改这一部分
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            splashColor: Colors.transparent, // 去除点击水波纹
            hoverColor: Colors.transparent, // 去除悬停背景
            focusColor: Colors.transparent, // 去除焦点背景
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: _isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedItems.add(item.name);
                        } else {
                          _selectedItems.remove(item.name);
                        }
                      });
                    },
                  )
                : (isFavorite
                      ? const Icon(Icons.favorite, color: Colors.red)
                      : ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle))),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: item.isHidden ? (isDark ? Colors.white38 : Colors.grey) : null,
                      decoration: item.isHidden ? TextDecoration.lineThrough : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (item.type == PlaylistType.system && !isFavorite) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('系统', style: TextStyle(fontSize: 10)),
                  ),
                ],
                if (item.type == PlaylistType.folder) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('文件夹', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ],
            ),
            trailing: _isSelectionMode
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.type == PlaylistType.custom)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '重命名',
                          onPressed: () => _renamePlaylist(item.name),
                        ),
                      IconButton(
                        icon: Icon(item.isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        color: item.isHidden ? (isDark ? Colors.white38 : Colors.grey) : AppColors.primary,
                        tooltip: item.isHidden ? '显示' : '隐藏',
                        onPressed: () => _toggleHidden(item.name),
                      ),
                    ],
                  ),
            onTap: _isSelectionMode
                ? () {
                    setState(() {
                      if (isSelected) {
                        _selectedItems.remove(item.name);
                      } else {
                        _selectedItems.add(item.name);
                      }
                    });
                  }
                : null,
          ),
        );
      },
    );
  }

  void _onReorder(List<PlaylistUiModel> playlists, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // Check if trying to move Favorites or move above Favorites
    final item = playlists[oldIndex];
    if (item.name == BaseConstants.likePlaylist) {
      // Cannot move favorites
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('收藏歌单固定置顶，不可移动')));
      return;
    }

    if (newIndex == 0 && playlists[0].name == BaseConstants.likePlaylist) {
      // Cannot move above favorites
      // But actually, newIndex refers to the position in the list.
      // If index 0 is Favorites, newIndex 0 means put before Favorites.
      // We can just clamp newIndex to 1 if Favorites exists.
      newIndex = 1;
    }

    final newPlaylists = List<PlaylistUiModel>.from(playlists);
    final movedItem = newPlaylists.removeAt(oldIndex);
    newPlaylists.insert(newIndex, movedItem);

    // Update sort order
    // We need to extract the names in the new order and save them
    // Logic in provider: [Favorites] + [New Custom] + [Sorted Existing] + [New System]
    // If we save the FULL list as the sort order, the provider logic needs to adapt or we rely on the provider using the sort order for everything in it.
    // Provider logic:
    // final sortedExisting = sortOrder.where((n) => remaining.contains(n)).toList();
    // It only respects items in `sortOrder`.
    // So if we save the entire list to `sortOrder`, then next time ALL items will be in `sortOrder`, so they will be in `sortedExisting`.
    // And `newCustom` and `newSystem` will be empty.
    // This is exactly what we want: once manually ordered, it becomes the explicit order.

    final newOrder = newPlaylists.map((e) => e.name).toList();
    ref.read(playlistSortOrderProvider.notifier).updateOrder(newOrder);
  }

  Future<void> _toggleHidden(String name) async {
    await ref.read(playlistHiddenStateProvider.notifier).toggleHidden(name);
  }

  Future<void> _batchHide(bool hide) async {
    final currentHidden = ref.read(playlistHiddenStateProvider);
    final newHidden = Set<String>.from(currentHidden);

    if (hide) {
      newHidden.addAll(_selectedItems);
    } else {
      newHidden.removeAll(_selectedItems);
    }

    await ref.read(playlistHiddenStateProvider.notifier).setHidden(newHidden.toList());

    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hide ? '已隐藏选中歌单' : '已显示选中歌单')));
    }
  }

  Future<void> _batchDelete() async {
    // Filter out system playlists and folder playlists
    final toDelete = _selectedItems.where((name) {
      // 需要重新获取一次列表来判断属性，或者依赖当前的 provider 数据
      // 这里简化处理，从 provider 读最新的列表来判断
      final playlists = ref.read(playlistUiListProvider).asData?.value ?? [];
      final item = playlists.firstWhere(
        (p) => p.name == name,
        // 如果找不到（理论上不应该发生），默认为受保护类型(System)，防止误删
        orElse: () => PlaylistUiModel(name: name, type: PlaylistType.system, isHidden: false),
      );

      // 统一使用 model 中的判断逻辑
      return item.type == PlaylistType.custom;
    }).toList();

    if (toDelete.length != _selectedItems.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('系统歌单或文件夹歌单不可删除，已自动忽略')));
    }

    if (toDelete.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${toDelete.length} 个歌单吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final name in toDelete) {
          await ref.read(playlistControllerProvider.notifier).deletePlaylist(name);
        }
        setState(() {
          _isSelectionMode = false;
          _selectedItems.clear();
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除成功')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
        }
      }
    }
  }

  Future<void> _renamePlaylist(String oldName) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => InputDialog(title: '重命名歌单', initialValue: oldName, confirmText: '保存', labelText: '歌单名称'),
    );

    if (newName != null && newName.isNotEmpty && newName != oldName) {
      try {
        await ref.read(playlistControllerProvider.notifier).renamePlaylist(oldName, newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('重命名成功')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
        }
      }
    }
  }
}
