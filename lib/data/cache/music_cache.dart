import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

/// 歌单缓存模型（手动序列化）
class PlaylistCache {
  final String name;
  final List<String> songs;
  final DateTime lastUpdated;

  PlaylistCache({required this.name, required this.songs, required this.lastUpdated});

  /// 从 API 数据创建
  factory PlaylistCache.fromApi({required String name, required List<String> songs}) {
    return PlaylistCache(name: name, songs: songs, lastUpdated: DateTime.now());
  }

  /// 从 Map 反序列化
  factory PlaylistCache.fromMap(Map<String, dynamic> map) {
    return PlaylistCache(
      name: map['name'] as String,
      songs: (map['songs'] as List).cast<String>(),
      lastUpdated: DateTime.parse(map['lastUpdated'] as String),
    );
  }

  /// 序列化为 Map
  Map<String, dynamic> toMap() {
    return {'name': name, 'songs': songs, 'lastUpdated': lastUpdated.toIso8601String()};
  }

  /// 判断是否需要刷新（超过 1 小时）
  bool get needsRefresh {
    return DateTime.now().difference(lastUpdated).inHours >= 1;
  }
}

/// 歌曲信息缓存模型（存储 URL 和 tags）
class SongInfoCache {
  final String name;
  final String url;
  final Map<String, dynamic> tags;
  final DateTime lastUpdated;
  final int? fileSize;

  SongInfoCache({required this.name, required this.url, required this.tags, required this.lastUpdated, this.fileSize});

  /// 从 API 数据创建
  factory SongInfoCache.fromApi({
    required String name,
    required String url,
    Map<String, dynamic>? tags,
    int? fileSize,
  }) {
    return SongInfoCache(name: name, url: url, tags: tags ?? {}, lastUpdated: DateTime.now(), fileSize: fileSize);
  }

  /// 从 Map 反序列化
  factory SongInfoCache.fromMap(Map<String, dynamic> map) {
    return SongInfoCache(
      name: map['name'] as String,
      url: map['url'] as String,
      tags: (map['tags'] as Map?)?.cast<String, dynamic>() ?? {},
      lastUpdated: DateTime.parse(map['lastUpdated'] as String),
      fileSize: map['fileSize'] as int?,
    );
  }

  /// 序列化为 Map
  Map<String, dynamic> toMap() {
    return {'name': name, 'url': url, 'tags': tags, 'lastUpdated': lastUpdated.toIso8601String(), 'fileSize': fileSize};
  }

  /// 复制并更新
  SongInfoCache copyWith({
    String? name,
    String? url,
    Map<String, dynamic>? tags,
    DateTime? lastUpdated,
    int? fileSize,
  }) {
    return SongInfoCache(
      name: name ?? this.name,
      url: url ?? this.url,
      tags: tags ?? this.tags,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  /// 获取图片 URL（从 tags 中提取）
  String? get pictureUrl {
    final picture = tags['picture'];
    if (picture == null || picture.toString().isEmpty) return null;
    return picture.toString();
  }

  /// 获取标题（从 tags 中提取，如果没有则使用 name）
  String get title {
    final title = tags['title'];
    if (title != null && title.toString().isNotEmpty) {
      return title.toString();
    }
    return name;
  }

  /// 获取艺术家（从 tags 中提取）
  String? get artist {
    final artist = tags['artist'];
    if (artist == null || artist.toString().isEmpty) return null;
    return artist.toString();
  }

  /// 获取专辑（从 tags 中提取）
  String? get album {
    final album = tags['album'];
    if (album == null || album.toString().isEmpty) return null;
    return album.toString();
  }
}

/// 播放器状态缓存模型（用于 Hive 存储）
class PlayerStateCache {
  final String? currentSong;
  final List<String> playlist;
  final int currentIndex;
  final int positionSeconds;
  final int durationSeconds;
  final bool isPlaying;
  final int loopModeIndex;
  final bool shuffleMode;
  final String? currentPlaylistName;
  final DateTime lastUpdated;

  PlayerStateCache({
    this.currentSong,
    required this.playlist,
    required this.currentIndex,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.isPlaying,
    required this.loopModeIndex,
    required this.shuffleMode,
    this.currentPlaylistName,
    required this.lastUpdated,
  });

  /// 从 Map 反序列化
  factory PlayerStateCache.fromMap(Map<String, dynamic> map) {
    return PlayerStateCache(
      currentSong: map['currentSong'] as String?,
      playlist: (map['playlist'] as List?)?.cast<String>() ?? [],
      currentIndex: map['currentIndex'] as int? ?? -1,
      positionSeconds: map['positionSeconds'] as int? ?? 0,
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      isPlaying: map['isPlaying'] as bool? ?? false,
      loopModeIndex: map['loopModeIndex'] as int? ?? 0,
      shuffleMode: map['shuffleMode'] as bool? ?? false,
      currentPlaylistName: map['currentPlaylistName'] as String?,
      lastUpdated: map['lastUpdated'] != null ? DateTime.parse(map['lastUpdated'] as String) : DateTime.now(),
    );
  }

  /// 序列化为 Map
  Map<String, dynamic> toMap() {
    return {
      'currentSong': currentSong,
      'playlist': playlist,
      'currentIndex': currentIndex,
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
      'isPlaying': isPlaying,
      'loopModeIndex': loopModeIndex,
      'shuffleMode': shuffleMode,
      'currentPlaylistName': currentPlaylistName,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// 音乐库缓存管理器
class MusicCacheManager {
  static const String _playlistBoxName = 'playlist_cache';
  static const String _songInfoBoxName = 'song_info_cache';
  static const String _playerStateBoxName = 'player_state_cache';

  Box<Map>? _playlistBox;
  Box<Map>? _songInfoBox;
  Box<Map>? _playerStateBox;

  /// 初始化 Hive
  Future<void> init() async {
    await Hive.initFlutter();
    _playlistBox = await Hive.openBox<Map>(_playlistBoxName);
    _songInfoBox = await Hive.openBox<Map>(_songInfoBoxName);
    _playerStateBox = await Hive.openBox<Map>(_playerStateBoxName);
  }

  /// 保存歌曲信息到缓存
  Future<void> saveSongInfo(SongInfoCache songInfo) async {
    await _songInfoBox?.put(songInfo.name, songInfo.toMap());
  }

  /// 批量保存歌曲信息
  Future<void> saveSongInfos(List<SongInfoCache> songInfos) async {
    for (final songInfo in songInfos) {
      await saveSongInfo(songInfo);
    }
  }

  /// 获取歌曲信息缓存
  SongInfoCache? getSongInfo(String songName) {
    final map = _songInfoBox?.get(songName);
    if (map == null) return null;
    try {
      return SongInfoCache.fromMap(Map<String, dynamic>.from(map));
    } catch (e) {
      _logger.e("反序列化歌曲信息 $songName 失败: $e");
      return null;
    }
  }

  /// 批量获取歌曲信息
  Map<String, SongInfoCache> getSongInfos(List<String> songNames) {
    final result = <String, SongInfoCache>{};
    for (final songName in songNames) {
      final info = getSongInfo(songName);
      if (info != null) {
        result[songName] = info;
      }
    }
    return result;
  }

  /// 删除歌曲信息缓存
  Future<void> deleteSongInfo(String songName) async {
    await _songInfoBox?.delete(songName);
  }

  /// 清空所有歌曲信息缓存
  Future<void> clearSongInfos() async {
    await _songInfoBox?.clear();
  }

  /// 保存歌单列表到缓存
  Future<void> savePlaylist(String name, List<String> songs) async {
    final cache = PlaylistCache.fromApi(name: name, songs: songs);
    await _playlistBox?.put(name, cache.toMap());
  }

  /// 保存多个歌单
  Future<void> savePlaylists(Map<String, List<String>> playlists) async {
    for (final entry in playlists.entries) {
      await savePlaylist(entry.key, entry.value);
    }
  }

  /// 获取歌单缓存
  PlaylistCache? getPlaylist(String name) {
    final map = _playlistBox?.get(name);
    if (map == null) return null;
    try {
      return PlaylistCache.fromMap(Map<String, dynamic>.from(map));
    } catch (e) {
      _logger.e("反序列化歌单 $name 失败: $e");
      return null;
    }
  }

  /// 获取所有歌单名称
  List<String> getAllPlaylistNames() {
    return _playlistBox?.keys.cast<String>().toList() ?? [];
  }

  /// 获取所有歌单（作为 Map）
  Map<String, List<String>> getAllPlaylists() {
    final map = <String, List<String>>{};
    if (_playlistBox != null) {
      for (final key in _playlistBox!.keys) {
        final cache = getPlaylist(key.toString());
        if (cache != null) {
          map[cache.name] = cache.songs;
        }
      }
    }
    return map;
  }

  /// 搜索歌曲（在所有歌单或指定歌单中）
  List<String> searchSongs(String query, {String? playlistName}) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final allSongs = <String>{};

    if (playlistName != null && playlistName != '全部') {
      final cache = getPlaylist(playlistName);
      if (cache != null) {
        allSongs.addAll(cache.songs);
      }
    } else if (_playlistBox != null) {
      for (final key in _playlistBox!.keys) {
        final cache = getPlaylist(key.toString());
        if (cache != null) {
          allSongs.addAll(cache.songs);
        }
      }
    }

    return allSongs.where((song) => song.toLowerCase().contains(lowerQuery)).toList();
  }

  /// 清空缓存（包括歌单和歌曲信息）
  Future<void> clearCache() async {
    await _playlistBox?.clear();
    await _songInfoBox?.clear();
  }

  /// 只清空歌单缓存（保留歌曲信息缓存）
  Future<void> clearPlaylists() async {
    await _playlistBox?.clear();
  }

  /// 删除指定歌单缓存
  Future<void> deletePlaylist(String name) async {
    await _playlistBox?.delete(name);
  }

  /// 检查是否有缓存
  bool get hasCache {
    return _playlistBox?.isNotEmpty ?? false;
  }

  /// 获取缓存更新时间
  DateTime? getLastUpdateTime() {
    if (_playlistBox == null || _playlistBox!.isEmpty) return null;

    DateTime? latest;
    for (final key in _playlistBox!.keys) {
      final cache = getPlaylist(key.toString());
      if (cache != null) {
        if (latest == null || cache.lastUpdated.isAfter(latest)) {
          latest = cache.lastUpdated;
        }
      }
    }
    return latest;
  }

  // ========== 播放器状态缓存（按设备隔离）==========

  /// 保存播放器状态到缓存
  /// [deviceKey] 设备标识（BaseConstants.webDevice 或设备 did）
  Future<void> savePlayerState(String deviceKey, PlayerStateCache state) async {
    if (_playerStateBox == null) {
      _logger.w("播放器状态 Box 未初始化，无法保存缓存: $deviceKey");
      return;
    }
    await _playerStateBox!.put(deviceKey, state.toMap());
  }

  /// 获取播放器状态缓存
  /// [deviceKey] 设备标识（BaseConstants.webDevice 或设备 did）
  PlayerStateCache? getPlayerState(String deviceKey) {
    if (_playerStateBox == null) {
      _logger.w("播放器状态 Box 未初始化，无法读取缓存: $deviceKey");
      return null;
    }
    final map = _playerStateBox!.get(deviceKey);
    if (map == null) return null;
    try {
      return PlayerStateCache.fromMap(Map<String, dynamic>.from(map));
    } catch (e) {
      _logger.e("反序列化播放器状态 $deviceKey 失败: $e");
      return null;
    }
  }

  /// 删除指定设备的播放器状态缓存
  Future<void> deletePlayerState(String deviceKey) async {
    await _playerStateBox?.delete(deviceKey);
  }

  /// 清除所有播放器状态缓存
  Future<void> clearPlayerStates() async {
    await _playerStateBox?.clear();
  }

  /// 关闭数据库
  Future<void> close() async {
    await _playlistBox?.close();
    await _songInfoBox?.close();
    await _playerStateBox?.close();
  }
}
