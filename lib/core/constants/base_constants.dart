/// 基础常量
class BaseConstants {
  BaseConstants._();
  // 当前版本
  static const String currentVersion = 'v1.1.1';
  // 本地设备默认ID
  static const String webDevice = 'web_device';
  // 收藏歌单名称
  static const String likePlaylist = '收藏';
  // 系统级别的歌单名称列表（不包括"收藏"，因为收藏需要置顶）
  static const Set<String> systemPlaylistNames = {'临时搜索列表', '所有歌曲', '所有电台', '全部', '下载', '其他', '最近新增'};
}
