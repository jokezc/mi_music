import 'package:flutter/material.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/presentation/widgets/song_cover.dart';

class SongMultiSelectPage extends StatefulWidget {
  final String title;
  final List<String> allSongs;
  final List<String> initialSelectedSongs;
  final String actionLabel;

  const SongMultiSelectPage({
    super.key,
    required this.title,
    required this.allSongs,
    this.initialSelectedSongs = const [],
    this.actionLabel = S.confirm,
  });

  @override
  State<SongMultiSelectPage> createState() => _SongMultiSelectPageState();
}

class _SongMultiSelectPageState extends State<SongMultiSelectPage> {
  late Set<String> _selectedSongs;
  late TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedSongs = widget.initialSelectedSongs.toSet();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredSongs = _query.isEmpty
        ? widget.allSongs
        : widget.allSongs.where((s) => s.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                if (_selectedSongs.length == filteredSongs.length) {
                  _selectedSongs.clear();
                } else {
                  _selectedSongs.addAll(filteredSongs);
                }
              });
            },
            child: Text(
              _selectedSongs.length == filteredSongs.length && filteredSongs.isNotEmpty ? '取消全选' : '全选',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onChanged: (val) {
                setState(() => _query = val);
              },
            ),
          ),
          Expanded(
            child: filteredSongs.isEmpty
                ? Center(
                    child: Text(
                      S.emptySongs,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      final isSelected = _selectedSongs.contains(song);
                      return CheckboxListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        secondary: SongCover(songName: song, size: 48),
                        title: Text(song, maxLines: 1, overflow: TextOverflow.ellipsis),
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedSongs.add(song);
                            } else {
                              _selectedSongs.remove(song);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: _selectedSongs.isEmpty
                ? null
                : () {
                    Navigator.pop(context, _selectedSongs.toList());
                  },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text('${widget.actionLabel} (${_selectedSongs.length})'),
          ),
        ),
      ),
    );
  }
}
