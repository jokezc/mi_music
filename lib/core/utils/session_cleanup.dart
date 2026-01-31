import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/cron_task_provider.dart';
import 'package:mi_music/data/providers/playlist_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';
import 'package:mi_music/data/providers/system_provider.dart';

final _logger = Logger();

/// 清除当前服务相关的所有缓存与状态。
/// 由调用方在「退出登录」或「连接页测连成功且地址变化」时触发。
///
/// 会执行：
/// - 清空歌单/歌曲信息（Hive）
/// - 清空所有设备播放状态（Hive，含本机设备的播放列表、当前曲、进度等）
/// - 清空设备音量缓存、当前设备 ID（SharedPreferences）
/// - 清空歌单隐藏状态与自定义排序（SharedPreferences，因新服务歌单列表不同）
/// - 停止播放状态轮询并销毁统一播放控制器
/// - 使缓存刷新、设备列表、歌单排序/隐藏、定时任务列表等 Provider 失效，下次从新服务拉取
///
/// 换地址后执行本方法可能带来的影响：
/// 1. 界面短暂 loading/空白：依赖播放器、缓存的页面会先重建，等新服务接口拉完才恢复。
/// 2. 首次进歌单/资料库会拉全量：缓存清空后第一次进入会触发全量同步，可能稍慢或耗流量。
/// 3. 当前设备会按新服务重新选：已清除保存的 currentDeviceId，会按新服务设备列表选第一个远程或本机。
Future<void> clearServerData(WidgetRef ref) async {
  try {
    await ref.read(initCacheProvider.future);
    final cacheManager = ref.read(cacheManagerProvider);
    await cacheManager.clearCache();
    await cacheManager.clearPlayerStates();
    _logger.i('已清空歌单、歌曲信息与播放器状态缓存（含本机播放状态）');

    final prefs = ref.read(sharedPreferencesProvider);
    await SharedPrefKeys.clearAllPlayerCache(prefs);
    await prefs.remove(SharedPrefKeys.currentDeviceId);
    await prefs.remove(SharedPrefKeys.playlistHiddenState);
    await prefs.remove(SharedPrefKeys.playlistSortOrder);
    _logger.i('已清空设备音量、当前设备 ID、歌单隐藏与排序');

    ref.invalidate(unifiedPlayerControllerProvider);
    ref.invalidate(cacheRefreshControllerProvider);
    ref.invalidate(playerDevicesProvider);
    ref.invalidate(playlistSortOrderProvider);
    ref.invalidate(playlistHiddenStateProvider);
    ref.invalidate(cronTaskListProvider);
    _logger.i('已失效播放控制器、缓存刷新、设备列表、歌单 UI 状态与定时任务列表');
  } catch (e, st) {
    _logger.e('clearServerData 失败: $e', error: e, stackTrace: st);
  }
}
