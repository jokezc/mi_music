import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/system_provider.dart';

final _logger = Logger();

/// 统一的设备选择底部表单组件
class DeviceSelectorSheet extends ConsumerWidget {
  const DeviceSelectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 获取设备列表（使用统一的 Provider）
    final devicesAsync = ref.watch(playerDevicesProvider);
    final devices = devicesAsync.value ?? {};

    // 获取当前设备（从播放器状态）
    final currentDevice = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentDevice));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.speaker_group, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    S.deviceSelector,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), tooltip: S.cancel),
              ],
            ),
          ),
          const Divider(height: 1),
          // 远程设备列表
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.devices_other, size: 48, color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint),
                  const SizedBox(height: 12),
                  Text(
                    S.noDevices,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices.values.elementAt(index);
                  final isSelected = currentDevice?.did == device.did;

                  final isLocalDevice = device.type == DeviceType.local;
                  
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : (isDark ? AppColors.darkSurface : AppColors.lightDivider),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isLocalDevice ? Icons.smartphone_rounded : Icons.speaker_rounded,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                        size: 24,
                      ),
                    ),
                    title: Text(device.name ?? '未知设备'),
                    subtitle: Text(
                      device.did,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () => _handleDeviceSelection(context, ref, device: device),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 处理设备选择
  Future<void> _handleDeviceSelection(BuildContext context, WidgetRef ref, {required Device device}) async {
    final playerStateAsync = ref.read(unifiedPlayerControllerProvider);
    final currentDevice = playerStateAsync.value?.currentDevice;
    final playerNotifier = ref.read(unifiedPlayerControllerProvider.notifier);

    // 如果选择的是当前设备，直接关闭
    if (currentDevice?.did == device.did) {
      Navigator.pop(context);
      return;
    }

    // 关闭底部表单
    Navigator.pop(context);

    try {
      // 切换设备（不依赖 context，即使页面已关闭也要执行）
      await playerNotifier.setDevice(device);

      // 显示成功提示（需要 context，所以检查 mounted）
      // if (context.mounted) {
      //   final deviceName = device.name ?? (device.type == DeviceType.local ? '本机播放' : '远程设备');
      //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已切换到: $deviceName')));
      // }
    } catch (e) {
      _logger.e("切换设备失败: $e");
      // 错误提示需要 context，所以检查 mounted
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('切换设备失败: $e')));
      }
    }
  }
}
