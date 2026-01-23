import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/utils/snackbar_utils.dart';
import 'package:mi_music/data/providers/settings_provider.dart';
import 'package:mi_music/data/providers/theme_provider.dart';

/// 客户端设置 Section
class ClientSection extends ConsumerWidget {
  const ClientSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final themeMode = ref.watch(themeControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 切换设备设置
          Text('切换设备设置', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                // 切换设备时暂停当前设备
                SwitchListTile(
                  title: const Text(S.pauseCurrentDeviceOnSwitch),
                  subtitle: const Text(S.pauseCurrentDeviceOnSwitchDesc),
                  value: settings.pauseCurrentDeviceOnSwitch,
                  onChanged: (value) {
                    settingsNotifier.setPauseCurrentDeviceOnSwitch(value);
                  },
                ),
                const Divider(height: 1),
                // 切换设备时同步播放内容
                SwitchListTile(
                  title: const Text(S.syncPlaybackOnSwitch),
                  subtitle: const Text(S.syncPlaybackOnSwitchDesc),
                  value: settings.syncPlaybackOnSwitch,
                  onChanged: (value) {
                    settingsNotifier.setSyncPlaybackOnSwitch(value);
                  },
                ),
                const Divider(height: 1),
                // 首页显示快速设备切换
                SwitchListTile(
                  title: const Text(S.showQuickDeviceSwitcher),
                  subtitle: const Text(S.showQuickDeviceSwitcherDesc),
                  value: settings.showQuickDeviceSwitcher,
                  onChanged: (value) {
                    settingsNotifier.setShowQuickDeviceSwitcher(value);
                  },
                ),
                const Divider(height: 1),
                // 固定快速设备切换栏
                SwitchListTile(
                  title: const Text(S.pinQuickDeviceSwitcher),
                  subtitle: const Text(S.pinQuickDeviceSwitcherDesc),
                  value: settings.pinQuickDeviceSwitcher,
                  onChanged: (value) {
                    settingsNotifier.setPinQuickDeviceSwitcher(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // 外观设置
          Text(
            S.appearanceSettings,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: RadioGroup<AppThemeMode>(
              groupValue: themeMode,
              onChanged: (value) {
                if (value != null && value != themeMode) {
                  _handleThemeModeChange(context, ref, value);
                }
              },
              child: Column(
                children: AppThemeMode.values.map((mode) {
                  return RadioListTile<AppThemeMode>(
                    value: mode,
                    title: Text(mode.displayName),
                    subtitle: Text(_getSubtitle(mode)),
                    secondary: Icon(mode.icon),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitle(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return '根据系统设置自动切换';
      case AppThemeMode.light:
        return '始终使用浅色主题';
      case AppThemeMode.dark:
        return '始终使用深色主题';
    }
  }

  void _handleThemeModeChange(BuildContext context, WidgetRef ref, AppThemeMode mode) {
    ref.read(themeControllerProvider.notifier).setThemeMode(mode).then((_) {
      if (context.mounted) {
        SnackBarUtils.showWarning(context, '主题已更改，请重启应用以应用新主题');
      }
    });
  }
}
