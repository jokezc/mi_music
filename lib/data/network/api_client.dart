import 'package:dio/dio.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:retrofit/retrofit.dart';

part 'api_client.g.dart';

// 后端API接口
@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  // System
  // 获取系统设置
  @GET("/getsetting")
  Future<SystemSetting> getSetting(@Query("need_device_list") bool needDeviceList);

  // 保存系统设置
  @POST("/savesetting")
  Future<String> saveSetting(@Body() SystemSetting setting);

  // 获取版本信息
  @GET("/getversion")
  Future<VersionResp> getVersion();

  // Player Control
  // 发送通用指令
  @POST("/cmd")
  Future<RetMsg> sendCmd(@Body() DidCmd cmd);

  // 播放歌曲
  @POST("/playmusic")
  Future<RetMsg> playMusic(@Body() DidPlayMusic body);

  // 播放歌单
  @POST("/playmusiclist")
  Future<RetMsg> playMusicList(@Body() DidPlayMusicList body);

  // 播放TTS
  @GET("/playtts")
  Future<RetMsg> playTts(@Query("did") String did, @Query("text") String text);

  // 播放URL
  @GET("/playurl")
  Future<List<PlayUrlItem>> playUrl(@Query("did") String did, @Query("url") String url);
  
  // 获取当前播放状态
  @GET("/playingmusic")
  Future<PlayingMusicResp> getPlayingMusic(@Query("did") String did, CancelToken? cancelToken);

  // 获取音量
  @GET("/getvolume")
  Future<VolumeResp> getVolume(@Query("did") String did);
  
  // 设置音量
  @POST("/setvolume")
  Future<SetVolumeResp> setVolume(@Body() DidVolume body);

  // Playlist & Music
  // 获取所有音乐列表,包含系统歌单和自定义歌单
  @GET("/musiclist")
  Future<MusicListResp> getMusicList();

  // 批量获取歌曲信息
  @GET("/musicinfos")
  Future<List<MusicInfoItem>> getMusicInfos(@Query("name") List<String>? names, @Query("musictag") bool musicTag);

  // 搜索歌曲
  @GET("/searchmusic")
  Future<List<String>> searchMusic(@Query("name") String name);

  // 获取当前播放列表名称
  @GET("/curplaylist")
  Future<String> getCurPlaylist(@Query("did") String did);

  // 查询自定义歌单列表
  @GET("/playlistnames")
  Future<PlaylistNamesResp> getPlaylistNames();
  // 创建自定义歌单
  @POST("/playlistadd")
  Future<RetMsg> playlistAdd(@Body() PlayListObj body);

  // 删除自定义歌单
  @POST("/playlistdel")
  Future<RetMsg> playlistDel(@Body() PlayListObj body);

  // 重命名自定义歌单
  @POST("/playlistupdatename")
  Future<RetMsg> playlistUpdateName(@Body() PlayListUpdateObj body);

  // 添加歌曲到自定义歌单
  @POST("/playlistaddmusic")
  Future<RetMsg> playlistAddMusic(@Body() PlayListMusicObj body);

  // 从自定义歌单移除歌曲
  @POST("/playlistdelmusic")
  Future<RetMsg> playlistDelMusic(@Body() PlayListMusicObj body);

  // 更新自定义歌单歌曲
  @POST("/playlistupdatemusic")
  Future<RetMsg> playlistUpdateMusic(@Body() PlayListMusicObj body);

  // 获取自定义歌单歌曲列表
  @GET("/playlistmusics")
  Future<PlaylistMusicsResp> getPlaylistMusics(@Query("name") String name);

  // 永久删除歌曲
  @POST("/delmusic")
  Future<String> delMusic(@Body() MusicItem body);

  // 获取音乐详情
  @GET("/musicinfo")
  Future<MusicInfoResp> getMusicInfo(@Query("name") String name, @Query("musictag") bool musicTag);

  // 设置音乐标签
  @POST("/setmusictag")
  Future<RetMsg> setMusicTag(@Body() MusicInfoObj body);

  // 刷新音乐标签
  @POST("/refreshmusictag")
  Future<RetMsg> refreshMusicTag();

  // 下载json
  @POST("/downloadjson")
  Future<DownloadJsonResp> downloadJson(@Body() UrlInfo body);

  // 下载歌单
  @POST("/downloadplaylist")
  Future<RetMsg> downloadPlaylist(@Body() DownloadPlayList body);

  // 下载单个歌曲
  @POST("/downloadonemusic")
  Future<RetMsg> downloadOneMusic(@Body() DownloadOneMusic body);

  // Note: uploadytdlpcookie requires Multipart, might need special handling if used.
}
