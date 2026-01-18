import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/presentation/widgets/shimmer_loading.dart';

/// 搜索页面
class SearchPage extends ConsumerStatefulWidget {
  final String? playlistName;
  final String? initialQuery;

  const SearchPage({this.playlistName, this.initialQuery, super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _searchController = TextEditingController(text: _query);
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

    final displayPlaylistName = widget.playlistName ?? '全部';

    return Scaffold(
      appBar: AppBar(
        title: Text(displayPlaylistName == '全部' ? S.navSearch : '搜索歌单: $displayPlaylistName'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: displayPlaylistName == '全部' ? S.searchHint : '搜索 $displayPlaylistName 中的歌曲...',
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
              onSubmitted: (val) {
                setState(() => _query = val.trim());
              },
              textInputAction: TextInputAction.search,
            ),
          ),
        ),
      ),
      body: _buildSearchResults(theme, isDark, displayPlaylistName),
    );
  }

  Widget _buildSearchResults(ThemeData theme, bool isDark, String displayPlaylistName) {
    if (_query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
            const SizedBox(height: 16),
            Text(
              S.enterKeyword,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // 使用缓存搜索
    return ref
        .watch(cachedSearchSongsProvider(_query, playlistName: displayPlaylistName))
        .when(
          data: (songs) {
            if (songs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_off, size: 80, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                    const SizedBox(height: 16),
                    Text(
                      S.noResults,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.music_note, color: Colors.white),
                  ),
                  title: Text(song, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_circle_outline),
                    color: AppColors.primary,
                    onPressed: () {
                      ref
                          .read(unifiedPlayerControllerProvider.notifier)
                          .playMusic(song, playlistName: displayPlaylistName);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.playing}: $song')));
                    },
                  ),
                  onTap: () {
                    ref
                        .read(unifiedPlayerControllerProvider.notifier)
                        .playMusic(song, playlistName: displayPlaylistName);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.playing}: $song')));
                  },
                );
              },
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
              ],
            ),
          ),
        );
  }
}
