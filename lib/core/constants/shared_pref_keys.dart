import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 键名统一管理
///
/// 使用说明：
/// 1. 所有 SharedPreferences 的 key 都应在此类中定义
/// 2. 按使用场景分类，便于查找和维护
/// 3. 每个 key 都有注释说明存储类型和用途
/// 4. 设备相关的 key 使用便捷方法生成
///
/// 好处：
/// - 集中管理：所有 key 在一个地方，易于查找和维护
/// - 避免冲突：统一命名规范，防止 key 重复
/// - 类型安全：使用常量而非字符串字面量
/// - 易于重构：修改 key 只需改一处
class SharedPrefKeys {
  SharedPrefKeys._(); // 私有构造函数，防止实例化

  // ========== 用户设置 ==========

  /// 服务器地址
  /// 类型: String
  /// 用途: 存储 API 服务器 URL
  static const String serverUrl = 'server_url';

  /// 用户名
  /// 类型: String
  /// 用途: 存储登录用户名
  static const String username = 'username';

  /// 密码
  /// 类型: String
  /// 用途: 存储登录密码
  static const String password = 'password';

  /// 切换设备时暂停当前设备
  /// 类型: Bool
  /// 默认值: true
  /// 用途: 控制切换设备时是否自动暂停当前设备(本地设备不支持)
  static const String pauseCurrentDeviceOnSwitch = 'pause_current_device_on_switch';

  /// 切换设备时同步播放进度
  /// 类型: Bool
  /// 默认值: false
  /// 用途: 控制切换设备时是否同步播放进度
  static const String syncPlaybackOnSwitch = 'sync_playback_on_switch';

  // ========== 应用偏好 ==========

  /// 主题模式
  /// 类型: Int (AppThemeMode.index)
  /// 默认值: 0 (system)
  /// 用途: 存储应用主题模式（系统/浅色/深色）
  static const String themeMode = 'theme_mode';

  /// 歌单隐藏状态
  /// 类型: List[String]
  /// 用途: 存储被隐藏的歌单名称列表
  static const String playlistHiddenState = 'playlist_hidden_state';

  /// 歌单自定义排序
  /// 类型: List[String]
  /// 用途: 存储歌单的自定义排序顺序
  static const String playlistSortOrder = 'playlist_sort_order';

  // ========== 播放器状态 ==========

  /// 当前选中的设备 ID
  /// 类型: String
  /// 用途: 存储用户最后选择的播放设备 ID
  static const String currentDeviceId = 'current_device_id';

  // ========== 播放器缓存（按设备隔离）==========
  // 注意：播放器状态（播放列表、当前歌曲等）已迁移到 Hive，不再使用 SharedPreferences
  // 以下只保留设备音量缓存，因为音量缓存仍使用 SharedPreferences

  /// 设备音量缓存（基础 key，需配合设备标识使用）
  /// 类型: Int
  /// 用途: 存储远程设备的最近一次音量值（0~100）
  static const String _cachedDeviceVolume = 'cached_device_volume';

  // ========== 便捷方法：生成设备相关的 key ==========

  /// 获取设备相关的 key（用于播放器状态缓存）
  ///
  /// [baseKey] 基础 key 名称
  /// [deviceKey] 设备标识（'local' 或设备 did）
  ///
  /// 返回: 拼接后的完整 key，格式为 '{baseKey}_{deviceKey}'
  static String keyForDevice(String baseKey, String deviceKey) {
    return '${baseKey}_$deviceKey';
  }

  // ========== 播放器缓存的便捷方法 ==========
  // 注意：播放器状态相关的便捷方法已移除，因为已迁移到 Hive

  /// 设备音量缓存 key（按设备）
  static String cachedDeviceVolume(String deviceKey) => keyForDevice(_cachedDeviceVolume, deviceKey);

  // ========== 常用操作方法 ==========

  /// 清除指定设备的播放器缓存
  ///
  /// [prefs] SharedPreferences 实例
  /// [deviceKey] 设备标识
  ///
  /// 注意：播放器状态（播放列表、当前歌曲等）已迁移到 Hive，此方法只清除设备音量缓存
  static Future<void> clearPlayerCacheForDevice(SharedPreferences prefs, String deviceKey) async {
    await prefs.remove(cachedDeviceVolume(deviceKey));
  }

  /// 清除所有播放器缓存（所有设备）
  ///
  /// [prefs] SharedPreferences 实例
  ///
  /// 注意：播放器状态已迁移到 Hive，此方法只清除设备音量缓存
  /// 会清除所有以 'cached_device_volume_' 开头的 key
  static Future<void> clearAllPlayerCache(SharedPreferences prefs) async {
    final keys = prefs.getKeys();
    final keysToRemove = keys.where((key) => key.startsWith('cached_device_volume_')).toList();

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  /// 清除用户设置（服务器地址、用户名、密码）
  ///
  /// [prefs] SharedPreferences 实例
  static Future<void> clearUserSettings(SharedPreferences prefs) async {
    await Future.wait([prefs.remove(serverUrl), prefs.remove(username), prefs.remove(password)]);
  }

  /// 清除所有应用数据
  ///
  /// [prefs] SharedPreferences 实例
  ///
  /// 警告：此操作会清除所有存储的数据，请谨慎使用
  static Future<void> clearAll(SharedPreferences prefs) async {
    await prefs.clear();
  }
}
