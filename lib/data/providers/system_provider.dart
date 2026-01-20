import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_provider.g.dart';

/// 统一的设备列表 Provider（本地设备 + 远程设备）
/// 直接调用 API 获取设备列表，当需要刷新时调用 invalidate 即可
@Riverpod(keepAlive: true)
Future<Map<String, Device>> playerDevices(Ref ref) async {
  // 创建本地设备
  const localDeviceId = 'web_device';
  final localDevice = Device(did: localDeviceId, name: '本机播放', type: DeviceType.local);

  // 直接调用 API 获取系统设置（只需要设备列表）
  final client = ref.watch(apiClientProvider);
  final settings = await client.getSetting(false);
  final remoteDevices = settings.devices ?? {};

  // 合并设备列表：本地设备 + 远程设备
  return <String, Device>{localDeviceId: localDevice, ...remoteDevices};
}
