import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/cmd_commands.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/system_provider.dart';

final _logger = Logger();

/// 首页快速设备切换组件
class QuickDeviceSwitcher extends ConsumerStatefulWidget {
  const QuickDeviceSwitcher({super.key});

  @override
  ConsumerState<QuickDeviceSwitcher> createState() => QuickDeviceSwitcherState();
}

class QuickDeviceSwitcherState extends ConsumerState<QuickDeviceSwitcher> with WidgetsBindingObserver {
  // 存储每个设备的播放状态
  Map<String, PlayingMusicResp?> _playingStatusMap = {};
  bool _isFetchingStatus = false;
  bool _isClosingAllDevices = false;
  CancelToken? _cancelToken;
  Animation<double>? _secondaryAnimation;
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 初始加载状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAllDevicesPlayingStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听路由遮挡动画状态
    // 当 secondaryAnimation 变为 dismissed 时，说明覆盖在当前页面之上的页面被移除了（pop）
    // 此时当前页面重新变得完全可见
    final route = ModalRoute.of(context);
    if (route != null && _secondaryAnimation != route.secondaryAnimation) {
      _secondaryAnimation?.removeStatusListener(_onSecondaryAnimationStatusChanged);
      _secondaryAnimation = route.secondaryAnimation;
      _secondaryAnimation?.addStatusListener(_onSecondaryAnimationStatusChanged);
    }
  }

  @override
  void dispose() {
    _secondaryAnimation?.removeStatusListener(_onSecondaryAnimationStatusChanged);
    WidgetsBinding.instance.removeObserver(this);
    _cancelToken?.cancel('Widget disposed');
    super.dispose();
  }

  /// 监听应用生命周期，从后台切回前台时刷新状态
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _logger.d("应用切回前台，刷新设备状态");
      _fetchAllDevicesPlayingStatus();
    }
  }

  void _onSecondaryAnimationStatusChanged(AnimationStatus status) {
    // _logger.d("secondaryAnimation 刷新设备状态状态变化: $status");
    // 当状态变为 dismissed 时，说明遮挡的页面完全消失了，当前页面可见
    if (status == AnimationStatus.dismissed) {
      _logger.d("页面重新可见（从其他页面返回），刷新设备状态");
      _fetchAllDevicesPlayingStatus();
    }
  }

  /// 当组件重新可见时（例如从其他页面返回），或者父组件重建时，尝试刷新
  @override
  void didUpdateWidget(QuickDeviceSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 这里可以根据需要触发刷新，但主要依赖 LibraryPage 的生命周期调用,触发频率很高不行
    // _logger.d("快速切换栏组件更新，尝试刷新设备状态");
  }

  /// 公开刷新方法，供父组件调用
  Future<void> refreshStatus() => _fetchAllDevicesPlayingStatus();

  /// 获取所有远程设备的播放状态
  Future<void> _fetchAllDevicesPlayingStatus({bool force = false}) async {
    if (!force && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      if (difference < const Duration(minutes: 1)) {
        _logger.d("快速切换栏刷新被限流，距离上次刷新: ${difference.inSeconds}秒");
        return;
      }
    }

    _logger.d("调用接口快速切换栏刷新设备状态11111111111111111111");
    if (_isFetchingStatus) return;

    _lastFetchTime = DateTime.now();

    final devicesAsync = ref.read(playerDevicesProvider);
    final devices = devicesAsync.value ?? {};

    if (devices.isEmpty) return;

    // 取消上一次的请求
    _cancelToken?.cancel('New fetch started');
    _cancelToken = CancelToken();

    _isFetchingStatus = true;

    try {
      final apiClient = ref.read(apiClientProvider);
      final remoteDevices = devices.values.where((d) => d.type == DeviceType.remote).toList();

      final futures = remoteDevices.map((device) async {
        try {
          // 传递 cancelToken
          final status = await apiClient.getPlayingMusic(device.did, _cancelToken);
          return MapEntry(device.did, status);
        } catch (e) {
          if (e is DioException && CancelToken.isCancel(e)) {
            // 如果是取消，抛出异常以便外层捕获
            rethrow;
          }
          // 静默失败，不打扰用户
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
        // 忽略取消异常
        return;
      }
      _logger.w('快速切换栏获取设备状态失败: $e');
      if (mounted) {
        setState(() {
          _isFetchingStatus = false;
        });
      }
    } finally {
      // 如果不是因为被取消而结束（例如正常完成或非取消异常），清除 token
      // 但如果是被新请求取消，新请求会设置新 token，所以这里要注意
      // 我们只在 token 匹配时清除
      // 简单处理：不做清除，下次请求会覆盖。或者在 dispose 时取消。
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
        _fetchAllDevicesPlayingStatus(force: true);

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
    final devicesAsync = ref.watch(playerDevicesProvider);

    return devicesAsync.when(
      data: (devices) {
        if (devices.isEmpty) return const SizedBox.shrink();

        final deviceList = devices.values.toList();
        // 如果有远程设备，显示关闭全部按钮,暂时不显示把太丑了
        final hasRemoteDevices = false;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 计算每项宽度，减去中间间距
              final itemWidth = (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...deviceList.map((device) {
                    return SizedBox(
                      width: itemWidth,
                      child: _DeviceCard(
                        device: device,
                        playingStatus: _playingStatusMap[device.did],
                        onTap: () => _handleDeviceSwitch(device),
                      ),
                    );
                  }),
                  if (hasRemoteDevices)
                    // ignore: dead_code,太丑了算了
                    SizedBox(
                      width: itemWidth,
                      child: _CloseAllCard(
                        onTap: _isClosingAllDevices ? null : _closeAllRemoteDevices,
                        isLoading: _isClosingAllDevices,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _handleDeviceSwitch(Device device) async {
    final playerNotifier = ref.read(unifiedPlayerControllerProvider.notifier);
    final currentDevice = ref.read(unifiedPlayerControllerProvider).value?.currentDevice;

    // 如果已经是当前设备，不做操作
    if (currentDevice?.did == device.did) return;

    try {
      await playerNotifier.setDevice(device);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已切换到: ${device.name ?? '未知设备'}'), duration: const Duration(seconds: 1)));
      }
    } catch (e) {
      _logger.e("切换设备失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('切换设备失败: $e')));
      }
    }
  }
}

class _DeviceCard extends ConsumerWidget {
  final Device device;
  final PlayingMusicResp? playingStatus;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, this.playingStatus, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 获取当前播放状态和选中设备
    final playerState = ref.watch(unifiedPlayerControllerProvider).value;
    final currentDevice = playerState?.currentDevice;
    final isSelected = currentDevice?.did == device.did;

    final isLocal = device.type == DeviceType.local;

    // 确定播放状态和歌曲名
    bool isPlaying;
    String currentMusic;

    if (isLocal) {
      // 本地设备：如果是当前选中设备，从 PlayerState 获取状态；否则认为未播放
      if (isSelected) {
        isPlaying = playerState?.isPlaying ?? false;
        currentMusic = playerState?.currentSong ?? '';
      } else {
        isPlaying = false;
        currentMusic = '';
      }
    } else {
      // 远程设备：优先使用 API 获取的状态
      isPlaying = playingStatus?.isPlaying ?? false;
      currentMusic = playingStatus?.curMusic ?? '';

      // 如果远程设备是当前选中设备，且 API 状态为空（可能尚未获取），尝试使用 PlayerState
      if (isSelected && playingStatus == null) {
        isPlaying = playerState?.isPlaying ?? false;
        currentMusic = playerState?.currentSong ?? '';
      }
    }

    // 背景色
    final backgroundColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.1)
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);

    final borderColor = isSelected ? AppColors.primary : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64, // 减小高度
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(12),
            // 如果未选中，添加轻微阴影以突出卡片感
            boxShadow: isSelected
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isLocal ? Icons.smartphone_rounded : Icons.speaker_rounded,
                    size: 20,
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      device.name ?? (isLocal ? '本机' : '未知设备'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primary : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPlaying) const Icon(Icons.graphic_eq_rounded, size: 16, color: AppColors.primary),
                ],
              ),
              Text(
                (currentMusic.isNotEmpty)
                    ? currentMusic
                    : (isSelected ? (isPlaying ? '正在播放' : '已暂停') : (isLocal ? '本机' : '点击切换')),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextHint : AppColors.lightTextHint,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseAllCard extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _CloseAllCard({this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurface.withValues(alpha: 0.5)
                : AppColors.lightSurface.withValues(alpha: 0.5),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isLoading
              ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stop_circle_outlined, color: Colors.red, size: 24),
                    const SizedBox(height: 4),
                    Text(
                      '一键关闭',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
