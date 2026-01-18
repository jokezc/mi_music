import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playlist_provider.g.dart';

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
  }

  Future<void> deletePlaylist(String name) async {
    await ref.read(apiClientProvider).playlistDel(PlayListObj(name: name));
    ref.invalidate(playlistNamesProvider);
  }

  Future<void> renamePlaylist(String oldName, String newName) async {
    await ref.read(apiClientProvider).playlistUpdateName(PlayListUpdateObj(oldname: oldName, newname: newName));
    ref.invalidate(playlistNamesProvider);
  }

  Future<void> addMusicToPlaylist(String playlistName, List<String> musicList) async {
    await ref.read(apiClientProvider).playlistAddMusic(PlayListMusicObj(name: playlistName, musicList: musicList));
    ref.invalidate(playlistMusicsProvider(playlistName));
    ref.invalidate(cachedPlaylistMusicsProvider(playlistName));
    ref.invalidate(cachedPlaylistSongsProvider(playlistName));
  }

  Future<void> removeMusicFromPlaylist(String playlistName, List<String> musicList) async {
    await ref.read(apiClientProvider).playlistDelMusic(PlayListMusicObj(name: playlistName, musicList: musicList));
    ref.invalidate(playlistMusicsProvider(playlistName));
    ref.invalidate(cachedPlaylistMusicsProvider(playlistName));
    ref.invalidate(cachedPlaylistSongsProvider(playlistName));
  }
}
