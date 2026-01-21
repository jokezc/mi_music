import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/core/utils/snackbar_utils.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';

final _logger = Logger();

/// 功能页面
class FunctionsPage extends ConsumerWidget {
  const FunctionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.navFunctions)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // // 设备选择卡片
            // const _DeviceSelectorCard(),
            // const SizedBox(height: 16),
            // // 播放控制卡片
            // const _PlayerControlCard(),
            // const SizedBox(height: 16),

            // 设备信息卡片
            const _DeviceInfoCard(),
            const SizedBox(height: 16),

            // 快捷操作卡片
            const _QuickActionsCard(),
            const SizedBox(height: 16),

            // 设置入口卡片
            const _SettingsCard(),
          ],
        ),
      ),
    );
  }
}

// 设备选择卡片已移除，统一使用 unifiedPlayerControllerProvider 管理设备

/// 播放控制卡片
// ignore: unused_element
class _PlayerControlCard extends ConsumerWidget {
  const _PlayerControlCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasValue = ref.watch(unifiedPlayerControllerProvider.select((s) => s.hasValue));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.play_circle_rounded, color: AppColors.secondary),
                ),
                const SizedBox(width: 12),
                Text(S.playerControl, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (hasValue)
              _buildControlContent(context, ref, theme, isDark)
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildControlContent(BuildContext context, WidgetRef ref, ThemeData theme, bool isDark) {
    final currentSong = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentSong ?? ''));
    final playlistName = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.currentPlaylistName ?? ''));
    final isPlaying = ref.watch(unifiedPlayerControllerProvider.select((s) => s.value?.isPlaying ?? false));

    return Column(
      children: [
        // 当前播放
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                currentSong.isNotEmpty ? currentSong : S.notPlaying,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              if (playlistName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${S.playlist}: $playlistName',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 控制按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 40,
              onPressed: () {
                ref.read(unifiedPlayerControllerProvider.notifier).sendCmd('上一首');
              },
              tooltip: S.previous,
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: Icon(isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded),
              iconSize: 56,
              color: AppColors.primary,
              onPressed: () {
                if (isPlaying) {
                  ref.read(unifiedPlayerControllerProvider.notifier).sendCmd('停止');
                } else {
                  ref.read(unifiedPlayerControllerProvider.notifier).sendCmd('播放');
                }
              },
              tooltip: isPlaying ? S.pause : S.play,
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 40,
              onPressed: () {
                ref.read(unifiedPlayerControllerProvider.notifier).sendCmd('下一首');
              },
              tooltip: S.next,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 音量控制
        const _VolumeControl(),
      ],
    );
  }
}

/// 音量控制
class _VolumeControl extends ConsumerStatefulWidget {
  const _VolumeControl();

  @override
  ConsumerState<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends ConsumerState<_VolumeControl> {
  double _volume = 50;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.volume_down_rounded, size: 24),
        Expanded(
          child: Slider(
            value: _volume,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${_volume.toInt()}',
            onChanged: (val) {
              setState(() => _volume = val);
            },
            onChangeEnd: (val) {
              ref.read(unifiedPlayerControllerProvider.notifier).setVolume(val.toInt());
            },
          ),
        ),
        const Icon(Icons.volume_up_rounded, size: 24),
      ],
    );
  }
}

/// 快捷操作卡片
class _QuickActionsCard extends ConsumerWidget {
  const _QuickActionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: AppColors.accent),
                ),
                const SizedBox(width: 12),
                Text(S.quickActions, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.record_voice_over_rounded, size: 18),
                  label: const Text(S.tts),
                  onPressed: () => _showTtsDialog(context, ref),
                ),
                ActionChip(
                  avatar: const Icon(Icons.terminal_rounded, size: 18),
                  label: const Text(S.customCommand),
                  onPressed: () => _showCmdDialog(context, ref),
                ),
                ActionChip(
                  avatar: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(S.refreshMusicTagCache),
                  onPressed: () => _refreshMusicTagCache(context, ref),
                ),
                ActionChip(
                  avatar: const Icon(Icons.schedule_rounded, size: 18),
                  label: const Text(S.scheduledTasks),
                  onPressed: () => context.push('/cron-task/list'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTtsDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.tts),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: S.ttsHint),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(unifiedPlayerControllerProvider.notifier).playTts(controller.text);
                SnackBarUtils.showMessage(context, S.commandSent);
              }
              Navigator.pop(context);
            },
            child: const Text(S.speak),
          ),
        ],
      ),
    );
  }

  void _showCmdDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.customCommand),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: S.customCommandHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(unifiedPlayerControllerProvider.notifier).sendCmd(controller.text);
                SnackBarUtils.showMessage(context, S.commandSent);
              }
              Navigator.pop(context);
            },
            child: const Text(S.send),
          ),
        ],
      ),
    );
  }

  void _refreshMusicTagCache(BuildContext context, WidgetRef ref) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final result = await apiClient.refreshMusicTag();
      if (context.mounted) {
        SnackBarUtils.showMessage(context, result.ret == 'OK' ? '刷新成功' : result.ret);
      }
    } catch (e) {
      _logger.e("刷新设备列表失败: $e");
      if (context.mounted) {
        SnackBarUtils.showError(context, '${S.error}: $e');
      }
    }
  }
}

/// 设备信息卡片
class _DeviceInfoCard extends ConsumerStatefulWidget {
  const _DeviceInfoCard();

  @override
  ConsumerState<_DeviceInfoCard> createState() => _DeviceInfoCardState();
}

class _DeviceInfoCardState extends ConsumerState<_DeviceInfoCard> {
  String? _localDeviceName;
  String? _localDeviceModel;
  String? _localDeviceId;
  SystemSetting? _systemSetting;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocalDeviceInfo();
    _loadSystemSettings();
  }

  Future<void> _loadSystemSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiClient = ref.read(apiClientProvider);
      final setting = await apiClient.getSetting(false);
      if (mounted) {
        setState(() {
          _systemSetting = setting;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e("获取设备列表失败: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLocalDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        setState(() {
          _localDeviceName = androidInfo.model.isNotEmpty ? androidInfo.model : 'Android设备';
          _localDeviceModel = androidInfo.model.isNotEmpty ? androidInfo.model : '-';
          _localDeviceId = androidInfo.id.isNotEmpty ? androidInfo.id : '-';
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        setState(() {
          _localDeviceName = iosInfo.name.isNotEmpty ? iosInfo.name : 'iOS设备';
          _localDeviceModel = iosInfo.model.isNotEmpty ? iosInfo.model : '-';
          _localDeviceId = iosInfo.identifierForVendor != null && iosInfo.identifierForVendor!.isNotEmpty
              ? iosInfo.identifierForVendor!
              : '-';
        });
      }
    } catch (e) {
      _logger.e("获取本地设备信息失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerStateAsync = ref.watch(unifiedPlayerControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 判断当前使用的设备
    final currentDevice = playerStateAsync.value?.currentDevice;
    final isLocalMode = currentDevice?.type == DeviceType.local;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.info_rounded, color: AppColors.info),
                ),
                const SizedBox(width: 12),
                Text(S.deviceInfo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (isLocalMode)
              // 本地模式：显示手机信息
              Column(
                children: [
                  _buildInfoRow(context, '设备名称', _localDeviceName ?? '本机播放'),
                  _buildInfoRow(context, '硬件型号', _localDeviceModel ?? '-'),
                  _buildInfoRow(context, '设备ID', _localDeviceId ?? '-'),
                ],
              )
            else
              // 远程模式：显示远程设备信息
              _buildRemoteDeviceInfo(context, theme, isDark, currentDevice),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteDeviceInfo(BuildContext context, ThemeData theme, bool isDark, Device? currentDevice) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Text(
        '${S.error}: $_error',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      );
    }

    if (_systemSetting == null) {
      return Text(
        S.noDevices,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      );
    }

    final devices = _systemSetting!.devices;
    if (devices == null || currentDevice == null || !devices.containsKey(currentDevice.did)) {
      return Text(
        S.noDevices,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      );
    }

    final device = devices[currentDevice.did]!;
    return Column(
      children: [
        _buildInfoRow(context, '设备名称', device.name ?? '-'),
        _buildInfoRow(context, '硬件型号', device.hardware ?? '-'),
        _buildInfoRow(context, '设备ID', currentDevice.did),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// 设置入口卡片
class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings_rounded, color: AppColors.warning),
                ),
                const SizedBox(width: 12),
                Text(S.settings, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            // 连接配置入口
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text(S.connectionConfig),
              subtitle: const Text('配置连接服务端的账号密码'),
              trailing: const Icon(Icons.chevron_right_rounded),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                context.push('/connection-config');
              },
            ),
            const Divider(),
            // 软件设置入口
            ListTile(
              leading: const Icon(Icons.settings_applications_rounded),
              title: const Text(S.softwareSettings),
              subtitle: const Text('外观设置和客户端配置选项'),
              trailing: const Icon(Icons.chevron_right_rounded),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                context.push('/client-settings');
              },
            ),
            const Divider(),
            // 服务器设置入口
            ListTile(
              leading: const Icon(Icons.dns_rounded),
              title: const Text(S.goToSettings),
              subtitle: const Text('后端服务配置'),
              trailing: const Icon(Icons.chevron_right_rounded),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                context.push('/settings');
              },
            ),
            const Divider(),
            // 关于入口
            ListTile(
              leading: const Icon(Icons.info_rounded),
              title: const Text(S.about),
              subtitle: const Text('应用版本和相关信息'),
              trailing: const Icon(Icons.chevron_right_rounded),
              contentPadding: EdgeInsets.zero,
              onTap: () {
                context.push('/about');
              },
            ),
          ],
        ),
      ),
    );
  }
}
