import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_provider.g.dart';

@Riverpod(keepAlive: true)
Future<SystemSetting> systemSetting(Ref ref) async {
  final client = ref.watch(apiClientProvider);
  return await client.getSetting(true);
}

/// 统一的设备列表 Provider（本地设备 + 远程设备）
/// 当远程设备列表更新时，自动响应更新
@Riverpod(keepAlive: true)
Future<Map<String, Device>> playerDevices(Ref ref) async {
  // 创建本地设备
  const localDeviceId = 'web_device';
  final localDevice = Device(did: localDeviceId, name: '本机播放', type: DeviceType.local);

  // 监听 systemSettingProvider，自动响应更新
  final settings = await ref.watch(systemSettingProvider.future);
  final remoteDevices = settings.devices ?? {};
  // 合并设备列表：本地设备 + 远程设备
  return <String, Device>{localDeviceId: localDevice, ...remoteDevices};
}