import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/cmd_commands.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/system_provider.dart';

final _logger = Logger();

/// 统一的设备选择底部表单组件
class DeviceSelectorSheet extends ConsumerStatefulWidget {
  final double bottomPadding;

  const DeviceSelectorSheet({super.key, this.bottomPadding = 16});

  @override
  ConsumerState<DeviceSelectorSheet> createState() => _DeviceSelectorSheetState();
}

class _DeviceSelectorSheetState extends ConsumerState<DeviceSelectorSheet> {
  // 存储每个设备的播放状态
  Map<String, PlayingMusicResp?> _playingStatusMap = {};
  bool _isClosingAllDevices = false;
  bool _isFetchingStatus = false; // 标记是否正在获取播放状态
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel('Widget disposed');
    super.dispose();
  }

  /// 获取所有远程设备的播放状态
  Future<void> _fetchAllDevicesPlayingStatus() async {
    // 如果正在获取中，避免重复调用
    if (_isFetchingStatus) return;

    final devicesAsync = ref.read(playerDevicesProvider);
    final devices = devicesAsync.value ?? {};

    if (devices.isEmpty) return;

    // 取消上一次的请求
    _cancelToken?.cancel('New fetch started');
    _cancelToken = CancelToken();

    // 标记为正在获取
    _isFetchingStatus = true;

    try {
      final apiClient = ref.read(apiClientProvider);
      final remoteDevices = devices.values.where((d) => d.type == DeviceType.remote).toList();

      // 并发获取所有远程设备的播放状态
      final futures = remoteDevices.map((device) async {
        try {
          final status = await apiClient.getPlayingMusic(device.did, _cancelToken);
          return MapEntry(device.did, status);
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) {
            rethrow;
          }
          _logger.w('获取设备 ${device.did} 播放状态失败: $e');
          return MapEntry(device.did, null);
        }
      });

      final results = await Future.wait(futures);
      final statusMap = Map<String, PlayingMusicResp?>.fromEntries(results);

      if (mounted) {
        setState(() {
          _playingStatusMap = statusMap;
          _isFetchingStatus = false;
        });
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        return;
      }
      _logger.e('获取设备播放状态失败: $e');
      if (mounted) {
        setState(() {
          _isFetchingStatus = false;
        });
      }
    }
  }

  /// 一键关闭所有远程设备
  Future<void> _closeAllRemoteDevices() async {
    final devicesAsync = ref.read(playerDevicesProvider);
    final devices = devicesAsync.value ?? {};

    if (devices.isEmpty) return;

    final remoteDevices = devices.values.where((d) => d.type == DeviceType.remote).toList();

    if (remoteDevices.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有远程设备')));
      }
      return;
    }

    setState(() {
      _isClosingAllDevices = true;
    });

    try {
      final apiClient = ref.read(apiClientProvider);

      // 并发发送停止命令到所有远程设备
      final futures = remoteDevices.map((device) async {
        try {
          await apiClient.sendCmd(DidCmd(did: device.did, cmd: PlayerCommands.stop));
          return true;
        } catch (e) {
          _logger.e('关闭设备 ${device.did} 失败: $e');
          return false;
        }
      });

      final results = await Future.wait(futures);
      final successCount = results.where((r) => r).length;
      final failCount = results.length - successCount;

      if (mounted) {
        setState(() {
          _isClosingAllDevices = false;
        });

        // 刷新播放状态
        _fetchAllDevicesPlayingStatus();

        // 显示结果提示
        String message;
        if (failCount == 0) {
          message = '已关闭所有远程设备';
        } else {
          message = '已关闭 $successCount 个设备，$failCount 个设备关闭失败';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      _logger.e('关闭所有远程设备失败: $e');
      if (mounted) {
        setState(() {
          _isClosingAllDevices = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('关闭设备失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 获取设备列表（使用统一的 Provider）
    final devicesAsync = ref.watch(playerDevicesProvider);
    final devices = devicesAsync.value ?? {};

    // 当设备列表加载完成且播放状态为空时，触发获取播放状态
    if (devices.isNotEmpty && _playingStatusMap.isEmpty && !_isFetchingStatus) {
      // 延迟一帧后获取，确保 build 完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchAllDevicesPlayingStatus();
      });
    }

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
                  child: const Icon(Icons.speaker_group_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    S.deviceSelector,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: S.cancel,
                ),
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
                  Icon(
                    Icons.devices_other_rounded,
                    size: 48,
                    color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                  ),
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
                padding: EdgeInsets.zero,
                itemCount: devices.length + (devices.isNotEmpty ? 1 : 0), // 设备数量 + 按钮（如果有设备）
                itemBuilder: (context, index) {
                  // 如果是最后一个 item 且有设备，显示关闭按钮
                  if (index == devices.length) {
                    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, widget.bottomPadding + safeAreaBottom),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isClosingAllDevices ? null : _closeAllRemoteDevices,
                          icon: _isClosingAllDevices
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.stop_circle_outlined),
                          label: Text(_isClosingAllDevices ? '正在关闭...' : '关闭所有远程设备'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    );
                  }

                  // 显示设备项
                  final device = devices.values.elementAt(index);
                  final isSelected = currentDevice?.did == device.did;

                  final isLocalDevice = device.type == DeviceType.local;

                  // 获取该设备的播放状态
                  final playingStatus = _playingStatusMap[device.did];
                  final isPlaying = playingStatus?.isPlaying ?? false;
                  final currentMusic = playingStatus?.curMusic ?? '';

                  // 确定 subtitle 显示内容
                  String subtitleText;
                  if (isLocalDevice) {
                    subtitleText = device.did;
                  } else {
                    subtitleText = currentMusic.isNotEmpty ? currentMusic : device.did;
                  }

                  // 确定 trailing 显示内容
                  Widget? trailingWidget;
                  if (isSelected) {
                    trailingWidget = const Icon(Icons.check_rounded, color: AppColors.primary);
                  } else if (isPlaying && !isLocalDevice) {
                    trailingWidget = Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 20);
                  }

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
                      subtitleText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: trailingWidget,
                    onTap: () => _handleDeviceSelection(context, ref, device: device),
                  );
                },
              ),
            ),
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
