import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playlist_provider.g.dart';

enum PlaylistType { system, custom, folder }

class PlaylistUiModel {
  final String name;
  final PlaylistType type;
  final bool isHidden;

  PlaylistUiModel({required this.name, required this.type, required this.isHidden});
}

@riverpod
class PlaylistSortOrder extends _$PlaylistSortOrder {
  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getStringList(SharedPrefKeys.playlistSortOrder) ?? [];
  }

  Future<void> updateOrder(List<String> newOrder) async {
    state = newOrder;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(SharedPrefKeys.playlistSortOrder, newOrder);
  }
}

@riverpod
class PlaylistHiddenState extends _$PlaylistHiddenState {
  @override
  Set<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return (prefs.getStringList(SharedPrefKeys.playlistHiddenState) ?? []).toSet();
  }

  Future<void> toggleHidden(String name) async {
    final newState = Set<String>.from(state);
    if (newState.contains(name)) {
      newState.remove(name);
    } else {
      newState.add(name);
    }
    state = newState;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(SharedPrefKeys.playlistHiddenState, newState.toList());
  }

  Future<void> setHidden(List<String> hiddenNames) async {
    state = hiddenNames.toSet();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(SharedPrefKeys.playlistHiddenState, hiddenNames);
  }
}

@riverpod
Future<List<PlaylistUiModel>> playlistUiList(Ref ref) async {
  final allNames = await ref.watch(cachedPlaylistNamesProvider.future);
  // 获取自定义歌单列表（通过 /playlistnames 接口）
  final customPlaylistResp = await ref.watch(playlistNamesProvider.future);
  final customNames = customPlaylistResp.names.toSet();

  final sortOrder = ref.watch(playlistSortOrderProvider);
  final hiddenState = ref.watch(playlistHiddenStateProvider);

  final systemNames = BaseConstants.systemPlaylistNames;

  final List<String> result = [];

  // 1. Favorites always first if present
  if (allNames.contains(BaseConstants.likePlaylist)) {
    result.add(BaseConstants.likePlaylist);
  }

  // 2. Identify remaining items
  final remaining = allNames.where((n) => n != BaseConstants.likePlaylist).toList();

  // 3. Separate into Sorted and Unsorted
  // We want to preserve the order in `sortOrder` for items that exist
  final sortedExisting = sortOrder.where((n) => remaining.contains(n)).toList();
  final unsorted = remaining.where((n) => !sortOrder.contains(n)).toList();

  // 4. Separate Unsorted into Custom (New) and System
  // Custom/New should go to top (after favorites)
  // System should go to bottom
  final newCustom = unsorted.where((n) => !systemNames.contains(n)).toList()..sort();
  final newSystem = unsorted.where((n) => systemNames.contains(n)).toList()..sort();

  // 5. Construct final list: [Favorites] + [New Custom] + [Sorted Existing] + [New System]
  // Wait, if I dragged a system playlist to sortOrder, it is in `sortedExisting`.
  // If I have a new custom playlist, it is in `newCustom`.

  // Combine
  result.addAll(newCustom);
  result.addAll(sortedExisting);
  result.addAll(newSystem);

  return result.map((name) {
    // 判断歌单类型
    PlaylistType type;
    if (systemNames.contains(name) || name == BaseConstants.likePlaylist) {
      type = PlaylistType.system;
    } else if (customNames.contains(name)) {
      type = PlaylistType.custom;
    } else {
      type = PlaylistType.folder;
    }

    return PlaylistUiModel(name: name, type: type, isHidden: hiddenState.contains(name));
  }).toList();
}

@riverpod
Future<PlaylistNamesResp> playlistNames(Ref ref) {
  return ref.watch(apiClientProvider).getPlaylistNames();
}

@riverpod
Future<PlaylistMusicsResp> playlistMusics(Ref ref, String playlistName) {
  return ref.watch(apiClientProvider).getPlaylistMusics(playlistName);
}

/// 使用缓存的歌单歌曲 provider（优先使用缓存，缓存不存在时从 API 获取）
@Riverpod(keepAlive: true)
Future<PlaylistMusicsResp> cachedPlaylistMusics(Ref ref, String playlistName) async {
  // 优先从缓存获取
  // 使用 ref.watch(...).future 来获取 Future，同时建立依赖关系
  final cachedSongs = await ref.watch(cachedPlaylistSongsProvider(playlistName).future);

  // 返回 PlaylistMusicsResp 格式
  return PlaylistMusicsResp(ret: 'ok', musics: cachedSongs);
}

@Riverpod(keepAlive: true)
class PlaylistController extends _$PlaylistController {
  @override
  void build() {}

  Future<void> createPlaylist(String name) async {
    await ref.read(apiClientProvider).playlistAdd(PlayListObj(name: name));
    ref.invalidate(playlistNamesProvider);
    await ref.read(cacheRefreshControllerProvider.notifier).refreshPlaylistsOnly();
  }

  Future<void> deletePlaylist(String name) async {
    await ref.read(apiClientProvider).playlistDel(PlayListObj(name: name));
    ref.invalidate(playlistNamesProvider);
    await ref.read(cacheRefreshControllerProvider.notifier).refreshPlaylistsOnly();
  }

  Future<void> renamePlaylist(String oldName, String newName) async {
    await ref.read(apiClientProvider).playlistUpdateName(PlayListUpdateObj(oldname: oldName, newname: newName));
    ref.invalidate(playlistNamesProvider);
    await ref.read(cacheRefreshControllerProvider.notifier).refreshPlaylistsOnly();
  }

  Future<void> addMusicToPlaylist(String playlistName, List<String> musicList) async {
    await ref.read(apiClientProvider).playlistAddMusic(PlayListMusicObj(name: playlistName, musicList: musicList));
    // 刷新指定歌单缓存（只刷新歌单结构，不获取歌曲详情）
    await ref.read(cacheRefreshControllerProvider.notifier).refreshPlaylistsOnly(playlistName: playlistName);
  }

  Future<void> removeMusicFromPlaylist(String playlistName, List<String> musicList) async {
    await ref.read(apiClientProvider).playlistDelMusic(PlayListMusicObj(name: playlistName, musicList: musicList));
    // 刷新指定歌单缓存（只刷新歌单结构，不获取歌曲详情）
    await ref.read(cacheRefreshControllerProvider.notifier).refreshPlaylistsOnly(playlistName: playlistName);
  }

  Future<void> updatePlaylistMusic(String playlistName, List<String> musicList) async {
    await ref.read(apiClientProvider).playlistUpdateMusic(PlayListMusicObj(name: playlistName, musicList: musicList));
    // 刷新指定歌单缓存（只刷新歌单结构，不获取歌曲详情）
    await ref.read(cacheRefreshControllerProvider.notifier).refreshPlaylistsOnly(playlistName: playlistName);
  }
}
