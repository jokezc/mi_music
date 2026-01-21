import 'package:dio/dio.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:retrofit/retrofit.dart';

part 'api_client.g.dart';

@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  // System
  @GET("/getsetting")
  Future<SystemSetting> getSetting(@Query("need_device_list") bool needDeviceList);

  @POST("/savesetting")
  Future<String> saveSetting(@Body() SystemSetting setting);

  @GET("/getversion")
  Future<VersionResp> getVersion();

  // Player Control
  @POST("/cmd")
  Future<RetMsg> sendCmd(@Body() DidCmd cmd);

  @POST("/playmusic")
  Future<RetMsg> playMusic(@Body() DidPlayMusic body);

  @POST("/playmusiclist")
  Future<RetMsg> playMusicList(@Body() DidPlayMusicList body);

  @GET("/playurl")
  Future<List<PlayUrlItem>> playUrl(@Query("did") String did, @Query("url") String url);

  @GET("/musicinfos")
  Future<List<MusicInfoItem>> getMusicInfos(@Query("name") List<String>? names, @Query("musictag") bool musicTag);

  @GET("/playtts")
  Future<RetMsg> playTts(@Query("did") String did, @Query("text") String text);

  @GET("/playingmusic")
  Future<PlayingMusicResp> getPlayingMusic(@Query("did") String did);

  @GET("/getvolume")
  Future<VolumeResp> getVolume(@Query("did") String did);

  @POST("/setvolume")
  Future<SetVolumeResp> setVolume(@Body() DidVolume body);

  // Playlist & Music
  @GET("/musiclist")
  Future<MusicListResp> getMusicList();

  @GET("/searchmusic")
  Future<List<String>> searchMusic(@Query("name") String name);

  @GET("/curplaylist")
  Future<String> getCurPlaylist(@Query("did") String did);

  @GET("/playlistnames")
  Future<PlaylistNamesResp> getPlaylistNames();

  @POST("/playlistadd")
  Future<RetMsg> playlistAdd(@Body() PlayListObj body);

  @POST("/playlistdel")
  Future<RetMsg> playlistDel(@Body() PlayListObj body);

  @POST("/playlistupdatename")
  Future<RetMsg> playlistUpdateName(@Body() PlayListUpdateObj body);

  @POST("/playlistaddmusic")
  Future<RetMsg> playlistAddMusic(@Body() PlayListMusicObj body);

  @POST("/playlistdelmusic")
  Future<RetMsg> playlistDelMusic(@Body() PlayListMusicObj body);

  @POST("/playlistupdatemusic")
  Future<RetMsg> playlistUpdateMusic(@Body() PlayListMusicObj body);

  // 获取歌单歌曲列表,但是目前仅支持自定义歌单
  @GET("/playlistmusics")
  Future<PlaylistMusicsResp> getPlaylistMusics(@Query("name") String name);

  @POST("/delmusic")
  Future<String> delMusic(@Body() MusicItem body);

  // Metadata
  @GET("/musicinfo")
  Future<MusicInfoResp> getMusicInfo(@Query("name") String name, @Query("musictag") bool musicTag);

  @POST("/setmusictag")
  Future<RetMsg> setMusicTag(@Body() MusicInfoObj body);

  @POST("/refreshmusictag")
  Future<RetMsg> refreshMusicTag();

  // Download
  @POST("/downloadjson")
  Future<DownloadJsonResp> downloadJson(@Body() UrlInfo body);

  @POST("/downloadplaylist")
  Future<RetMsg> downloadPlaylist(@Body() DownloadPlayList body);

  @POST("/downloadonemusic")
  Future<RetMsg> downloadOneMusic(@Body() DownloadOneMusic body);

  // Note: uploadytdlpcookie requires Multipart, might need special handling if used.
}
