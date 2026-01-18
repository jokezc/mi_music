import 'package:json_annotation/json_annotation.dart';

part 'api_models.g.dart';

String? safeString(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

/// 安全地将 Map 值转换为 String，处理 null 值
Map<String, String>? safeStringMap(dynamic json) {
  if (json == null) return null;
  if (json is! Map<String, dynamic>) return null;
  return json.map((k, e) => MapEntry(k, e?.toString() ?? ''));
}

/// 安全地将 List 值转换为 String，过滤 null 值
List<String>? safeStringList(dynamic json) {
  if (json == null) return null;
  if (json is! List<dynamic>) return null;
  return json.where((e) => e != null).map((e) => e.toString()).toList();
}

/// 设备类型枚举
enum DeviceType {
  local,
  remote;

  /// 从字符串转换为枚举
  static DeviceType fromString(String value) {
    switch (value) {
      case 'local':
        return DeviceType.local;
      case 'remote':
        return DeviceType.remote;
      default:
        return DeviceType.remote;
    }
  }

  /// 转换为字符串（用于 JSON 序列化）
  String toValue() {
    switch (this) {
      case DeviceType.local:
        return 'local';
      case DeviceType.remote:
        return 'remote';
    }
  }
}

@JsonSerializable()
class DidCmd {
  final String did;
  final String cmd;

  DidCmd({required this.did, required this.cmd});

  factory DidCmd.fromJson(Map<String, dynamic> json) => _$DidCmdFromJson(json);
  Map<String, dynamic> toJson() => _$DidCmdToJson(this);
}

@JsonSerializable()
class DidPlayMusic {
  final String did;
  @JsonKey(defaultValue: "")
  final String musicname;
  @JsonKey(defaultValue: "")
  final String searchkey;
  @JsonKey(defaultValue: "")
  final String listname;

  DidPlayMusic({required this.did, String? musicname, String? searchkey, String? listname})
    : musicname = musicname ?? "",
      searchkey = searchkey ?? "",
      listname = listname ?? "";

  factory DidPlayMusic.fromJson(Map<String, dynamic> json) => _$DidPlayMusicFromJson(json);
  Map<String, dynamic> toJson() => _$DidPlayMusicToJson(this);
}

@JsonSerializable()
class DidPlayMusicList {
  final String did;
  @JsonKey(defaultValue: "")
  final String listname;
  @JsonKey(defaultValue: "")
  final String musicname;

  DidPlayMusicList({required this.did, String? listname, String? musicname})
    : listname = listname ?? "",
      musicname = musicname ?? "";

  factory DidPlayMusicList.fromJson(Map<String, dynamic> json) => _$DidPlayMusicListFromJson(json);
  Map<String, dynamic> toJson() => _$DidPlayMusicListToJson(this);
}

@JsonSerializable()
class DidVolume {
  final String did;
  @JsonKey(defaultValue: 0)
  final int volume;

  DidVolume({required this.did, int? volume}) : volume = volume ?? 0;

  factory DidVolume.fromJson(Map<String, dynamic> json) => _$DidVolumeFromJson(json);
  Map<String, dynamic> toJson() => _$DidVolumeToJson(this);
}

@JsonSerializable()
class MusicInfoObj {
  final String musicname;
  @JsonKey(defaultValue: "")
  final String title;
  @JsonKey(defaultValue: "")
  final String artist;
  @JsonKey(defaultValue: "")
  final String album;
  @JsonKey(defaultValue: "")
  final String year;
  @JsonKey(defaultValue: "")
  final String genre;
  @JsonKey(defaultValue: "")
  final String lyrics;
  @JsonKey(defaultValue: "")
  final String picture;

  MusicInfoObj({
    required this.musicname,
    String? title,
    String? artist,
    String? album,
    String? year,
    String? genre,
    String? lyrics,
    String? picture,
  }) : title = title ?? "",
       artist = artist ?? "",
       album = album ?? "",
       year = year ?? "",
       genre = genre ?? "",
       lyrics = lyrics ?? "",
       picture = picture ?? "";

  factory MusicInfoObj.fromJson(Map<String, dynamic> json) => _$MusicInfoObjFromJson(json);
  Map<String, dynamic> toJson() => _$MusicInfoObjToJson(this);
}

@JsonSerializable()
class PlayListObj {
  @JsonKey(defaultValue: "")
  final String name;

  PlayListObj({String? name}) : name = name ?? "";

  factory PlayListObj.fromJson(Map<String, dynamic> json) => _$PlayListObjFromJson(json);
  Map<String, dynamic> toJson() => _$PlayListObjToJson(this);
}

@JsonSerializable()
class PlayListUpdateObj {
  final String oldname;
  final String newname;

  PlayListUpdateObj({required this.oldname, required this.newname});

  factory PlayListUpdateObj.fromJson(Map<String, dynamic> json) => _$PlayListUpdateObjFromJson(json);
  Map<String, dynamic> toJson() => _$PlayListUpdateObjToJson(this);
}

@JsonSerializable()
class PlayListMusicObj {
  @JsonKey(defaultValue: "")
  final String name;
  @JsonKey(name: 'music_list')
  final List<String> musicList;

  PlayListMusicObj({String? name, required this.musicList}) : name = name ?? "";

  factory PlayListMusicObj.fromJson(Map<String, dynamic> json) => _$PlayListMusicObjFromJson(json);
  Map<String, dynamic> toJson() => _$PlayListMusicObjToJson(this);
}

@JsonSerializable()
class MusicItem {
  final String name;

  MusicItem({required this.name});

  factory MusicItem.fromJson(Map<String, dynamic> json) => _$MusicItemFromJson(json);
  Map<String, dynamic> toJson() => _$MusicItemToJson(this);
}

@JsonSerializable()
class UrlInfo {
  final String url;

  UrlInfo({required this.url});

  factory UrlInfo.fromJson(Map<String, dynamic> json) => _$UrlInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UrlInfoToJson(this);
}

@JsonSerializable()
class DownloadPlayList {
  final String dirname;
  final String url;

  DownloadPlayList({required this.dirname, required this.url});

  factory DownloadPlayList.fromJson(Map<String, dynamic> json) => _$DownloadPlayListFromJson(json);
  Map<String, dynamic> toJson() => _$DownloadPlayListToJson(this);
}

@JsonSerializable()
class DownloadOneMusic {
  @JsonKey(defaultValue: "")
  final String name;
  final String url;

  DownloadOneMusic({String? name, required this.url}) : name = name ?? "";

  factory DownloadOneMusic.fromJson(Map<String, dynamic> json) => _$DownloadOneMusicFromJson(json);
  Map<String, dynamic> toJson() => _$DownloadOneMusicToJson(this);
}

@JsonSerializable()
class Device {
  final String did;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  final String? hardware;
  final String? name;
  @JsonKey(name: 'play_type')
  final int? playType;
  @JsonKey(name: 'cur_music')
  final String? curMusic;
  @JsonKey(name: 'cur_playlist')
  final String? curPlaylist;
  @JsonKey(fromJson: _deviceTypeFromJson, toJson: _deviceTypeToJson)
  final DeviceType type;

  Device({
    required this.did,
    this.deviceId,
    this.hardware,
    this.name,
    this.playType,
    this.curMusic,
    this.curPlaylist,
    DeviceType? type,
  }) : type = type ?? DeviceType.remote;

  static DeviceType _deviceTypeFromJson(String? value) {
    return value == null ? DeviceType.remote : DeviceType.fromString(value);
  }

  static String _deviceTypeToJson(DeviceType type) => type.toValue();

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}

@JsonSerializable()
class DeviceListItem {
  @JsonKey(name: 'deviceID')
  final String? deviceID;
  final String? serialNumber;
  final String? name;
  final String? alias;
  final bool? current;
  final String? presence;
  final String? address;
  final String? miotDID;
  final String? hardware;
  final String? romVersion;
  final String? romChannel;
  final Map<String, dynamic>? capabilities;
  final String? remoteCtrlType;
  final String? deviceSNProfile;
  final String? deviceProfile;
  final String? brokerEndpoint;
  final int? brokerIndex;
  final String? mac;
  final String? ssid;

  DeviceListItem({
    this.deviceID,
    this.serialNumber,
    this.name,
    this.alias,
    this.current,
    this.presence,
    this.address,
    this.miotDID,
    this.hardware,
    this.romVersion,
    this.romChannel,
    this.capabilities,
    this.remoteCtrlType,
    this.deviceSNProfile,
    this.deviceProfile,
    this.brokerEndpoint,
    this.brokerIndex,
    this.mac,
    this.ssid,
  });

  factory DeviceListItem.fromJson(Map<String, dynamic> json) => _$DeviceListItemFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceListItemToJson(this);
}

@JsonSerializable()
class SystemSetting {
  final String account;
  final String password;
  @JsonKey(name: 'mi_did')
  final String miDid;
  final String? cookie;
  final bool? verbose;
  @JsonKey(name: 'music_path')
  final String? musicPath;
  @JsonKey(name: 'temp_path')
  final String? tempPath;
  @JsonKey(name: 'download_path')
  final String? downloadPath;
  @JsonKey(name: 'conf_path')
  final String? confPath;
  @JsonKey(name: 'cache_dir')
  final String? cacheDir;
  final String? hostname;
  final int? port;
  @JsonKey(name: 'public_port')
  final int? publicPort;
  final String? proxy;
  final String? loudnorm;
  @JsonKey(name: 'search_prefix')
  final String? searchPrefix;
  @JsonKey(name: 'ffmpeg_location')
  final String? ffmpegLocation;
  @JsonKey(name: 'get_duration_type')
  final String? getDurationType;
  @JsonKey(name: 'active_cmd')
  final String? activeCmd;
  @JsonKey(name: 'exclude_dirs')
  final String? excludeDirs;
  @JsonKey(name: 'ignore_tag_dirs')
  final String? ignoreTagDirs;
  @JsonKey(name: 'music_path_depth')
  final int? musicPathDepth;
  @JsonKey(name: 'disable_httpauth')
  final bool? disableHttpAuth;
  @JsonKey(name: 'httpauth_username')
  final String? httpAuthUsername;
  @JsonKey(name: 'httpauth_password')
  final String? httpAuthPassword;
  @JsonKey(name: 'music_list_url')
  final String? musicListUrl;
  @JsonKey(name: 'music_list_json')
  final String? musicListJson;
  @JsonKey(name: 'custom_play_list_json')
  final String? customPlayListJson;
  @JsonKey(name: 'disable_download')
  final bool? disableDownload;
  @JsonKey(name: 'key_word_dict', fromJson: safeStringMap)
  final Map<String, String>? keyWordDict;
  @JsonKey(name: 'key_match_order', fromJson: safeStringList)
  final List<String>? keyMatchOrder;
  @JsonKey(name: 'use_music_api', fromJson: safeString)
  final String? useMusicApi;
  @JsonKey(name: 'use_music_audio_id')
  final String? useMusicAudioId;
  @JsonKey(name: 'use_music_id')
  final String? useMusicId;
  @JsonKey(name: 'log_file')
  final String? logFile;
  @JsonKey(name: 'fuzzy_match_cutoff')
  final double? fuzzyMatchCutoff;
  @JsonKey(name: 'enable_fuzzy_match')
  final bool? enableFuzzyMatch;
  @JsonKey(name: 'stop_tts_msg')
  final String? stopTtsMsg;
  @JsonKey(name: 'enable_config_example')
  final bool? enableConfigExample;
  @JsonKey(name: 'keywords_playlocal')
  final String? keywordsPlayLocal;
  @JsonKey(name: 'keywords_search_playlocal')
  final String? keywordsSearchPlayLocal;
  @JsonKey(name: 'keywords_play', fromJson: safeString)
  final String? keywordsPlay;
  @JsonKey(name: 'keywords_search_play')
  final String? keywordsSearchPlay;
  @JsonKey(name: 'keywords_stop', fromJson: safeString)
  final String? keywordsStop;
  @JsonKey(name: 'keywords_playlist')
  final String? keywordsPlaylist;
  @JsonKey(name: 'user_key_word_dict', fromJson: safeStringMap)
  final Map<String, String>? userKeyWordDict;
  @JsonKey(name: 'enable_force_stop')
  final bool? enableForceStop;
  final Map<String, Device>? devices;
  @JsonKey(name: 'group_list')
  final String? groupList;
  @JsonKey(name: 'remove_id3tag')
  final bool? removeId3Tag;
  @JsonKey(name: 'convert_to_mp3')
  final bool? convertToMp3;
  @JsonKey(name: 'delay_sec', fromJson: safeString)
  final String? delaySec;
  @JsonKey(name: 'continue_play', fromJson: safeString)
  final String? continuePlay;
  @JsonKey(name: 'enable_file_watch')
  final bool? enableFileWatch;
  @JsonKey(name: 'file_watch_debounce')
  final int? fileWatchDebounce;
  @JsonKey(name: 'pull_ask_sec')
  final int? pullAskSec;
  @JsonKey(name: 'enable_pull_ask')
  final bool? enablePullAsk;
  @JsonKey(name: 'crontab_json', fromJson: safeString)
  final String? crontabJson;
  @JsonKey(name: 'enable_yt_dlp_cookies')
  final bool? enableYtDlpCookies;
  @JsonKey(name: 'enable_save_tag')
  final bool? enableSaveTag;
  @JsonKey(name: 'enable_analytics')
  final bool? enableAnalytics;
  @JsonKey(name: 'get_ask_by_mina')
  final bool? getAskByMina;
  @JsonKey(name: 'play_type_one_tts_msg')
  final String? playTypeOneTtsMsg;
  @JsonKey(name: 'play_type_all_tts_msg')
  final String? playTypeAllTtsMsg;
  @JsonKey(name: 'play_type_rnd_tts_msg')
  final String? playTypeRndTtsMsg;
  @JsonKey(name: 'play_type_sin_tts_msg')
  final String? playTypeSinTtsMsg;
  @JsonKey(name: 'play_type_seq_tts_msg')
  final String? playTypeSeqTtsMsg;
  @JsonKey(name: 'recently_added_playlist_len')
  final int? recentlyAddedPlaylistLen;
  @JsonKey(name: 'enable_cmd_del_music')
  final bool? enableCmdDelMusic;
  @JsonKey(name: 'search_music_count')
  final int? searchMusicCount;
  @JsonKey(name: 'web_music_proxy')
  final bool? webMusicProxy;
  @JsonKey(name: 'device_list')
  final List<DeviceListItem>? deviceList;

  SystemSetting({
    this.account = "",
    this.password = "",
    this.miDid = "",
    this.cookie,
    this.verbose,
    this.musicPath,
    this.tempPath,
    this.downloadPath,
    this.confPath,
    this.cacheDir,
    this.hostname,
    this.port,
    this.publicPort,
    this.proxy,
    this.loudnorm,
    this.searchPrefix,
    this.ffmpegLocation,
    this.getDurationType,
    this.activeCmd,
    this.excludeDirs,
    this.ignoreTagDirs,
    this.musicPathDepth,
    this.disableHttpAuth,
    this.httpAuthUsername,
    this.httpAuthPassword,
    this.musicListUrl,
    this.musicListJson,
    this.customPlayListJson,
    this.disableDownload,
    this.keyWordDict,
    this.keyMatchOrder,
    this.useMusicApi,
    this.useMusicAudioId,
    this.useMusicId,
    this.logFile,
    this.fuzzyMatchCutoff,
    this.enableFuzzyMatch,
    this.stopTtsMsg,
    this.enableConfigExample,
    this.keywordsPlayLocal,
    this.keywordsSearchPlayLocal,
    this.keywordsPlay,
    this.keywordsSearchPlay,
    this.keywordsStop,
    this.keywordsPlaylist,
    this.userKeyWordDict,
    this.enableForceStop,
    this.devices,
    this.groupList,
    this.removeId3Tag,
    this.convertToMp3,
    this.delaySec,
    this.continuePlay,
    this.enableFileWatch,
    this.fileWatchDebounce,
    this.pullAskSec,
    this.enablePullAsk,
    this.crontabJson,
    this.enableYtDlpCookies,
    this.enableSaveTag,
    this.enableAnalytics,
    this.getAskByMina,
    this.playTypeOneTtsMsg,
    this.playTypeAllTtsMsg,
    this.playTypeRndTtsMsg,
    this.playTypeSinTtsMsg,
    this.playTypeSeqTtsMsg,
    this.recentlyAddedPlaylistLen,
    this.enableCmdDelMusic,
    this.searchMusicCount,
    this.webMusicProxy,
    this.deviceList,
  });

  factory SystemSetting.fromJson(Map<String, dynamic> json) => _$SystemSettingFromJson(json);
  Map<String, dynamic> toJson() => _$SystemSettingToJson(this);
}

// Responses

@JsonSerializable()
class RetMsg {
  final String ret;

  RetMsg({required this.ret});

  factory RetMsg.fromJson(Map<String, dynamic> json) => _$RetMsgFromJson(json);
  Map<String, dynamic> toJson() => _$RetMsgToJson(this);
}

@JsonSerializable()
class CmdStatusResp {
  final String ret;
  final String status;

  CmdStatusResp({required this.ret, required this.status});

  factory CmdStatusResp.fromJson(Map<String, dynamic> json) => _$CmdStatusRespFromJson(json);
  Map<String, dynamic> toJson() => _$CmdStatusRespToJson(this);
}

@JsonSerializable()
class VolumeResp {
  final int volume;

  VolumeResp({required this.volume});

  factory VolumeResp.fromJson(Map<String, dynamic> json) => _$VolumeRespFromJson(json);
  Map<String, dynamic> toJson() => _$VolumeRespToJson(this);
}

@JsonSerializable()
class SetVolumeResp {
  final String ret;
  final int volume;

  SetVolumeResp({required this.ret, required this.volume});

  factory SetVolumeResp.fromJson(Map<String, dynamic> json) => _$SetVolumeRespFromJson(json);
  Map<String, dynamic> toJson() => _$SetVolumeRespToJson(this);
}

@JsonSerializable()
class PlayingMusicResp {
  final String ret;
  @JsonKey(name: 'is_playing')
  final bool isPlaying;
  @JsonKey(name: 'cur_music')
  final String curMusic;
  @JsonKey(name: 'cur_playlist')
  final String curPlaylist;
  final num offset;
  final num duration;

  PlayingMusicResp({
    required this.ret,
    required this.isPlaying,
    required this.curMusic,
    required this.curPlaylist,
    required this.offset,
    required this.duration,
  });

  factory PlayingMusicResp.fromJson(Map<String, dynamic> json) => _$PlayingMusicRespFromJson(json);
  Map<String, dynamic> toJson() => _$PlayingMusicRespToJson(this);
}

@JsonSerializable()
class PlaylistMusicsResp {
  final String ret;
  final List<String> musics;

  PlaylistMusicsResp({required this.ret, required this.musics});

  factory PlaylistMusicsResp.fromJson(Map<String, dynamic> json) => _$PlaylistMusicsRespFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistMusicsRespToJson(this);
}

@JsonSerializable()
class PlaylistNamesResp {
  final String ret;
  final List<String> names;

  PlaylistNamesResp({required this.ret, required this.names});

  factory PlaylistNamesResp.fromJson(Map<String, dynamic> json) => _$PlaylistNamesRespFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistNamesRespToJson(this);
}

// 不使用 @JsonSerializable，因为 API 返回的 JSON 本身就是 Map<String, List<String>>
// 而不是包含 'playlists' 键的对象
class MusicListResp {
  final Map<String, List<String>> playlists;

  MusicListResp({required this.playlists});

  factory MusicListResp.fromJson(Map<String, dynamic> json) {
    return MusicListResp(
      playlists: json.map((key, value) => MapEntry(key, (value as List<dynamic>).map((e) => e as String).toList())),
    );
  }

  Map<String, dynamic> toJson() {
    return playlists.map((key, value) => MapEntry(key, value));
  }
}

@JsonSerializable()
class DownloadJsonResp {
  final String ret;
  final String content;

  DownloadJsonResp({required this.ret, required this.content});

  factory DownloadJsonResp.fromJson(Map<String, dynamic> json) => _$DownloadJsonRespFromJson(json);
  Map<String, dynamic> toJson() => _$DownloadJsonRespToJson(this);
}

@JsonSerializable()
class UploadCookieResp {
  final String ret;
  final String filename;
  @JsonKey(name: 'file_location')
  final String fileLocation;

  UploadCookieResp({required this.ret, required this.filename, required this.fileLocation});

  factory UploadCookieResp.fromJson(Map<String, dynamic> json) => _$UploadCookieRespFromJson(json);
  Map<String, dynamic> toJson() => _$UploadCookieRespToJson(this);
}

@JsonSerializable()
class VersionResp {
  final String version;

  VersionResp({required this.version});

  factory VersionResp.fromJson(Map<String, dynamic> json) => _$VersionRespFromJson(json);
  Map<String, dynamic> toJson() => _$VersionRespToJson(this);
}

@JsonSerializable()
class LatestVersionResp {
  final String ret;
  @JsonKey(defaultValue: "")
  final String version;

  LatestVersionResp({required this.ret, String? version}) : version = version ?? "";

  factory LatestVersionResp.fromJson(Map<String, dynamic> json) => _$LatestVersionRespFromJson(json);
  Map<String, dynamic> toJson() => _$LatestVersionRespToJson(this);
}

@JsonSerializable()
class MusicInfoResp {
  final String ret;
  final String name;
  final String url;
  @JsonKey(defaultValue: {})
  final Map<String, dynamic> tags;

  MusicInfoResp({required this.ret, required this.name, required this.url, Map<String, dynamic>? tags})
    : tags = tags ?? const {};

  factory MusicInfoResp.fromJson(Map<String, dynamic> json) => _$MusicInfoRespFromJson(json);
  Map<String, dynamic> toJson() => _$MusicInfoRespToJson(this);
}

@JsonSerializable()
class WsTokenResp {
  final String token;
  @JsonKey(name: 'expire_in')
  final int expireIn;

  WsTokenResp({required this.token, required this.expireIn});

  factory WsTokenResp.fromJson(Map<String, dynamic> json) => _$WsTokenRespFromJson(json);
  Map<String, dynamic> toJson() => _$WsTokenRespToJson(this);
}

@JsonSerializable()
class PlayUrlItem {
  final String ret;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  final String? status;

  PlayUrlItem({required this.ret, this.deviceId, this.status});

  factory PlayUrlItem.fromJson(Map<String, dynamic> json) => _$PlayUrlItemFromJson(json);
  Map<String, dynamic> toJson() => _$PlayUrlItemToJson(this);
}

@JsonSerializable()
class MusicInfoItem {
  final String name;
  final String url;
  @JsonKey(defaultValue: {})
  final Map<String, dynamic> tags;

  MusicInfoItem({required this.name, required this.url, Map<String, dynamic>? tags}) : tags = tags ?? const {};

  factory MusicInfoItem.fromJson(Map<String, dynamic> json) => _$MusicInfoItemFromJson(json);
  Map<String, dynamic> toJson() => _$MusicInfoItemToJson(this);
}

// Deprecated or Aliases kept for compatibility if needed, but updated logic should use above Resps.
// Keeping VersionInfo as alias to VersionResp if needed or just replace usage.
// Keeping PlayingMusic as it might be used in UI state, but response is PlayingMusicResp.

@JsonSerializable()
class PlayingMusic {
  @JsonKey(name: 'cur_music')
  final String curMusic;
  @JsonKey(name: 'cur_playlist')
  final String curPlaylist;
  @JsonKey(name: 'is_playing')
  final bool isPlaying;
  final int offset;
  final int duration;

  PlayingMusic({String? curMusic, String? curPlaylist, bool? isPlaying, int? offset, int? duration})
    : curMusic = curMusic ?? "",
      curPlaylist = curPlaylist ?? "",
      isPlaying = isPlaying ?? false,
      offset = offset ?? 0,
      duration = duration ?? 0;

  factory PlayingMusic.fromJson(Map<String, dynamic> json) => _$PlayingMusicFromJson(json);
  Map<String, dynamic> toJson() => _$PlayingMusicToJson(this);
}

@JsonSerializable()
class VersionInfo {
  final String version;

  VersionInfo({required this.version});

  factory VersionInfo.fromJson(Map<String, dynamic> json) => _$VersionInfoFromJson(json);
  Map<String, dynamic> toJson() => _$VersionInfoToJson(this);
}

@JsonSerializable()
class PlaylistNames {
  final List<String> names;

  PlaylistNames({required this.names});

  factory PlaylistNames.fromJson(Map<String, dynamic> json) => _$PlaylistNamesFromJson(json);
  Map<String, dynamic> toJson() => _$PlaylistNamesToJson(this);
}

/// 定时任务类型枚举
enum CronTaskType {
  stop,
  play,
  playMusicList,
  tts,
  refreshMusicList,
  setVolume,
  setPlayType,
  setPullAsk,
  reinit,
  playMusicTmpList;

  /// 从字符串转换为枚举
  static CronTaskType fromString(String value) {
    switch (value) {
      case 'stop':
        return CronTaskType.stop;
      case 'play':
        return CronTaskType.play;
      case 'play_music_list':
        return CronTaskType.playMusicList;
      case 'tts':
        return CronTaskType.tts;
      case 'refresh_music_list':
        return CronTaskType.refreshMusicList;
      case 'set_volume':
        return CronTaskType.setVolume;
      case 'set_play_type':
        return CronTaskType.setPlayType;
      case 'set_pull_ask':
        return CronTaskType.setPullAsk;
      case 'reinit':
        return CronTaskType.reinit;
      case 'play_music_tmp_list':
        return CronTaskType.playMusicTmpList;
      default:
        return CronTaskType.play;
    }
  }

  /// 转换为字符串（用于 JSON 序列化）
  String toValue() {
    switch (this) {
      case CronTaskType.stop:
        return 'stop';
      case CronTaskType.play:
        return 'play';
      case CronTaskType.playMusicList:
        return 'play_music_list';
      case CronTaskType.tts:
        return 'tts';
      case CronTaskType.refreshMusicList:
        return 'refresh_music_list';
      case CronTaskType.setVolume:
        return 'set_volume';
      case CronTaskType.setPlayType:
        return 'set_play_type';
      case CronTaskType.setPullAsk:
        return 'set_pull_ask';
      case CronTaskType.reinit:
        return 'reinit';
      case CronTaskType.playMusicTmpList:
        return 'play_music_tmp_list';
    }
  }
}

/// 定时任务模型
@JsonSerializable()
class CronTask {
  final String expression;
  @JsonKey(name: 'name', fromJson: _taskTypeFromJson, toJson: _taskTypeToJson)
  final CronTaskType type;
  final String? did;
  @JsonKey(name: 'arg1')
  final String? arg1;
  @JsonKey(name: 'music_list')
  final List<String>? musicList;
  final String? first;

  CronTask({
    required this.expression,
    required this.type,
    this.did,
    this.arg1,
    this.musicList,
    this.first,
  });

  static CronTaskType _taskTypeFromJson(String? value) {
    if (value == null) return CronTaskType.play;
    return CronTaskType.fromString(value);
  }

  static String _taskTypeToJson(CronTaskType type) => type.toValue();

  factory CronTask.fromJson(Map<String, dynamic> json) => _$CronTaskFromJson(json);
  Map<String, dynamic> toJson() => _$CronTaskToJson(this);

  /// 创建副本
  CronTask copyWith({
    String? expression,
    CronTaskType? type,
    String? did,
    String? arg1,
    List<String>? musicList,
    String? first,
  }) {
    return CronTask(
      expression: expression ?? this.expression,
      type: type ?? this.type,
      did: did ?? this.did,
      arg1: arg1 ?? this.arg1,
      musicList: musicList ?? this.musicList,
      first: first ?? this.first,
    );
  }
}
