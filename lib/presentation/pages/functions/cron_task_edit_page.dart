import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/core/utils/snackbar_utils.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/cron_task_provider.dart';
import 'package:mi_music/data/providers/system_provider.dart';

final _logger = Logger();

/// 定时任务编辑页面
class CronTaskEditPage extends ConsumerStatefulWidget {
  final CronTask? task;
  final int index;

  const CronTaskEditPage({super.key, this.task, required this.index});

  @override
  ConsumerState<CronTaskEditPage> createState() => _CronTaskEditPageState();
}

class _CronTaskEditPageState extends ConsumerState<CronTaskEditPage> {
  late final TextEditingController _expressionController;
  late final TextEditingController _didController;
  late final TextEditingController _arg1Controller;
  late final TextEditingController _firstController;
  late final List<TextEditingController> _musicListControllers;

  CronTaskType _selectedType = CronTaskType.play;
  String? _selectedDid;
  int? _selectedPlayType;
  String? _selectedPullAsk;
  String? _nextExecutionTime;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _expressionController = TextEditingController(text: task.expression);
      _didController = TextEditingController(text: task.did ?? '');
      _arg1Controller = TextEditingController(text: task.arg1 ?? '');
      _firstController = TextEditingController(text: task.first ?? '');
      _selectedType = task.type;
      _selectedDid = task.did;
      _musicListControllers = (task.musicList ?? []).map((e) => TextEditingController(text: e)).toList();
      if (task.type == CronTaskType.setPlayType && task.arg1 != null) {
        _selectedPlayType = int.tryParse(task.arg1!);
      }
      if (task.type == CronTaskType.setPullAsk && task.arg1 != null) {
        _selectedPullAsk = task.arg1;
      }
    } else {
      _expressionController = TextEditingController();
      _didController = TextEditingController();
      _arg1Controller = TextEditingController();
      _firstController = TextEditingController();
      _musicListControllers = [];
    }
    // 监听 cron 表达式变化
    _expressionController.addListener(_onExpressionChanged);
    // 初始化计算
    _onExpressionChanged();
  }

  @override
  void dispose() {
    _expressionController.dispose();
    _didController.dispose();
    _arg1Controller.dispose();
    _firstController.dispose();
    for (var controller in _musicListControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onExpressionChanged() {
    final expression = _expressionController.text.trim();
    if (expression.isEmpty) {
      setState(() {
        _nextExecutionTime = null;
      });
      return;
    }
    // 法定节假日先不解析,后续再处理
    if (expression.contains("#")) {
      setState(() {
        _nextExecutionTime = '法定时间暂不支持';
      });
      return;
    }
    // 移除 #workday 和 #offday 后缀
    final cleanExpression = expression.split('#').first.trim();
    final nextTime = _calculateNextExecutionTime(cleanExpression);
    setState(() {
      _nextExecutionTime = nextTime;
    });
  }

  void _onTypeChanged(CronTaskType? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      // 清空参数
      _arg1Controller.clear();
      _selectedPlayType = null;
      _selectedPullAsk = null;
    });
  }

  void _addMusicListItem() {
    setState(() {
      _musicListControllers.add(TextEditingController());
    });
  }

  void _removeMusicListItem(int index) {
    setState(() {
      _musicListControllers[index].dispose();
      _musicListControllers.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_expressionController.text.trim().isEmpty) {
      SnackBarUtils.showError(context, S.invalidCronExpression);
      return;
    }

    try {
      String? arg1;
      List<String>? musicList;
      String? first;

      // 根据任务类型处理参数
      switch (_selectedType) {
        case CronTaskType.setPlayType:
          if (_selectedPlayType == null) {
            SnackBarUtils.showError(context, '请选择播放类型');
            return;
          }
          arg1 = _selectedPlayType.toString();
          break;
        case CronTaskType.setPullAsk:
          if (_selectedPullAsk == null) {
            SnackBarUtils.showError(context, '请选择启用/禁用');
            return;
          }
          arg1 = _selectedPullAsk;
          break;
        case CronTaskType.playMusicTmpList:
          musicList = _musicListControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
          if (musicList.isEmpty) {
            SnackBarUtils.showError(context, '请至少添加一首歌曲');
            return;
          }
          first = _firstController.text.trim();
          arg1 = _arg1Controller.text.trim(); // 临时列表名称
          break;
        case CronTaskType.reinit:
        case CronTaskType.refreshMusicList:
          // 不需要参数
          break;
        default:
          if (_arg1Controller.text.trim().isEmpty) {
            SnackBarUtils.showError(context, '请输入任务参数');
            return;
          }
          arg1 = _arg1Controller.text.trim();
      }

      final task = CronTask(
        expression: _expressionController.text.trim(),
        type: _selectedType,
        did: _didController.text.trim().isEmpty ? null : _didController.text.trim(),
        arg1: arg1?.isEmpty ?? true ? null : arg1,
        musicList: musicList?.isEmpty ?? true ? null : musicList,
        first: first?.isEmpty ?? true ? null : first,
      );

      if (widget.index >= 0) {
        await ref.read(cronTaskListProvider.notifier).updateTask(widget.index, task);
      } else {
        await ref.read(cronTaskListProvider.notifier).addTask(task);
      }

      if (mounted) {
        SnackBarUtils.showMessage(context, S.taskSaved);
        context.pop();
      }
    } catch (e) {
      _logger.e("保存定时任务失败: $e");
      if (mounted) {
        SnackBarUtils.showError(context, '${S.taskSaveFailed}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicesAsync = ref.watch(playerDevicesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.task == null ? S.addScheduledTask : S.editScheduledTask)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 快捷表达式选择
            _buildQuickExpressionSelector(),
            const SizedBox(height: 16),

            // Cron表达式
            TextField(
              controller: _expressionController,
              decoration: InputDecoration(
                labelText: S.cronExpression,
                hintText: S.cronExpressionHint,
                helperText: _nextExecutionTime != null
                    ? '${S.cronExpressionHelp} · 下次执行: $_nextExecutionTime'
                    : S.cronExpressionHelp,
                helperMaxLines: 5,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.schedule_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline_rounded),
                  tooltip: S.cronExpressionHelp,
                  onPressed: () => _showCronHelpDialog(context),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 设备ID选择
            devicesAsync.when(
              data: (devices) {
                // 过滤出远程设备，排除本地设备
                final remoteDevices = devices.values.where((d) => d.type == DeviceType.remote).toList();
                // 如果还没有选中设备且是新建任务，默认选中第一个远程设备
                if (widget.task == null && _selectedDid == null && remoteDevices.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedDid == null) {
                      setState(() {
                        _selectedDid = remoteDevices.first.did;
                        _didController.text = remoteDevices.first.did;
                      });
                    }
                  });
                }
                // 如果当前选中的是本地设备，清空选择
                if (_selectedDid != null) {
                  final selectedDevice = devices[_selectedDid];
                  if (selectedDevice != null && selectedDevice.type == DeviceType.local) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedDid = remoteDevices.isNotEmpty ? remoteDevices.first.did : null;
                          _didController.text = _selectedDid ?? '';
                        });
                      }
                    });
                  }
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedDid,
                  decoration: InputDecoration(
                    labelText: S.deviceId,
                    hintText: S.deviceIdHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.devices_rounded),
                  ),
                  items: [
                    ...remoteDevices.map((device) {
                      final displayName = device.name ?? device.did;
                      return DropdownMenuItem(value: device.did, child: Text('$displayName (${device.did})'));
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDid = value;
                      _didController.text = value ?? '';
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => TextField(
                controller: _didController,
                decoration: InputDecoration(
                  labelText: S.deviceId,
                  hintText: S.deviceIdHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.devices_rounded),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 任务类型
            DropdownButtonFormField<CronTaskType>(
              initialValue: _selectedType,
              decoration: InputDecoration(
                labelText: S.taskType,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.category_rounded),
              ),
              items: CronTaskType.values.map((type) {
                return DropdownMenuItem(value: type, child: Text(_getTaskTypeName(type)));
              }).toList(),
              onChanged: _onTypeChanged,
            ),
            const SizedBox(height: 16),

            // 根据任务类型显示不同的参数输入
            _buildParameterInput(),
            const SizedBox(height: 24),

            // 保存按钮
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(S.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterInput() {
    switch (_selectedType) {
      case CronTaskType.setPlayType:
        return _buildPlayTypeSelector();
      case CronTaskType.setPullAsk:
        return _buildPullAskSelector();
      case CronTaskType.playMusicTmpList:
        return _buildMusicTmpListInput();
      case CronTaskType.reinit:
      case CronTaskType.refreshMusicList:
        return const SizedBox.shrink();
      default:
        return TextField(
          controller: _arg1Controller,
          decoration: InputDecoration(
            labelText: S.taskParameter,
            hintText: _getParameterHint(_selectedType),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.edit_rounded),
          ),
        );
    }
  }

  Widget _buildPlayTypeSelector() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedPlayType,
      decoration: InputDecoration(
        labelText: S.taskParameter,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.shuffle_rounded),
      ),
      items: const [
        DropdownMenuItem(value: 0, child: Text('单曲循环')),
        DropdownMenuItem(value: 1, child: Text('全部循环')),
        DropdownMenuItem(value: 2, child: Text('随机播放')),
        DropdownMenuItem(value: 3, child: Text('单曲播放')),
        DropdownMenuItem(value: 4, child: Text('顺序播放')),
      ],
      onChanged: (value) {
        setState(() {
          _selectedPlayType = value;
        });
      },
    );
  }

  Widget _buildPullAskSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPullAsk,
      decoration: InputDecoration(
        labelText: S.taskParameter,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.settings_voice_rounded),
      ),
      items: const [
        DropdownMenuItem(value: 'enable', child: Text('启用')),
        DropdownMenuItem(value: 'disable', child: Text('禁用')),
      ],
      onChanged: (value) {
        setState(() {
          _selectedPullAsk = value;
        });
      },
    );
  }

  Widget _buildMusicTmpListInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _arg1Controller,
          decoration: InputDecoration(
            labelText: '临时列表名称',
            hintText: '例如：临时列表1',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.playlist_play_rounded),
          ),
        ),
        const SizedBox(height: 16),
        Text(S.musicList, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...List.generate(_musicListControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _musicListControllers[index],
                    decoration: InputDecoration(labelText: '歌曲 ${index + 1}', border: const OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.error,
                  onPressed: () => _removeMusicListItem(index),
                ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _addMusicListItem,
          icon: const Icon(Icons.add_rounded),
          label: const Text('添加歌曲'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _firstController,
          decoration: InputDecoration(
            labelText: S.firstSong,
            hintText: S.firstSongHint,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.play_arrow_rounded),
          ),
        ),
      ],
    );
  }

  String _getTaskTypeName(CronTaskType type) {
    switch (type) {
      case CronTaskType.stop:
        return S.taskTypeStop;
      case CronTaskType.play:
        return S.taskTypePlay;
      case CronTaskType.playMusicList:
        return S.taskTypePlayMusicList;
      case CronTaskType.tts:
        return S.taskTypeTts;
      case CronTaskType.refreshMusicList:
        return S.taskTypeRefreshMusicList;
      case CronTaskType.setVolume:
        return S.taskTypeSetVolume;
      case CronTaskType.setPlayType:
        return S.taskTypeSetPlayType;
      case CronTaskType.setPullAsk:
        return S.taskTypeSetPullAsk;
      case CronTaskType.reinit:
        return S.taskTypeReinit;
      case CronTaskType.playMusicTmpList:
        return S.taskTypePlayMusicTmpList;
    }
  }

  String _getParameterHint(CronTaskType type) {
    switch (type) {
      case CronTaskType.play:
        return '例如：周杰伦晴天';
      case CronTaskType.playMusicList:
        return '例如：周杰伦 或 周杰伦|晴天';
      case CronTaskType.tts:
        return '例如：早上好！该起床了！';
      case CronTaskType.setVolume:
        return '例如：25 (0-100)';
      default:
        return S.taskParameterHint;
    }
  }

  /// 快捷表达式选项
  static const List<Map<String, String>> _quickExpressions = [
    {'name': '每天 8:00', 'expression': '0 8 * * *'},
    {'name': '周一到周五 8:00', 'expression': '0 8 * * 0-4'},
    {'name': '周末 9:00', 'expression': '0 9 * * 5-6'},
    {'name': '每小时整点', 'expression': '0 * * * *'},
    {'name': '法定工作日 8:00', 'expression': '0 8 * * * #workday'},
    {'name': '休息日 10:00', 'expression': '0 10 * * * #offday'},
  ];

  Widget _buildQuickExpressionSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  S.quickExpression,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickExpressions.map((item) {
                return ActionChip(
                  label: Text(item['name']!),
                  onPressed: () {
                    setState(() {
                      _expressionController.text = item['expression']!;
                    });
                  },
                  avatar: const Icon(Icons.schedule_rounded, size: 16),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showCronHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.cronExpressionExample),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Cron表达式格式：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('分 时 日 月 星期', style: TextStyle(fontFamily: 'monospace', fontSize: 16)),
              const SizedBox(height: 16),
              const Text('常用示例：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildHelpItem('0 8 * * *', '每天8点'),
              _buildHelpItem('0 8 * * 0-4', '周一到周五每天8点'),
              _buildHelpItem('30 10 * * *', '每天10点30分'),
              _buildHelpItem('0 */2 * * *', '每2小时'),
              _buildHelpItem('*/15 * * * *', '每15分钟'),
              _buildHelpItem('0 0 * * *', '每天0点（午夜）'),
              const SizedBox(height: 16),
              const Text('星期说明：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('0=周一, 1=周二, 2=周三, 3=周四, 4=周五, 5=周六, 6=周日'),
              const Text('0-4 表示周一到周五'),
              const Text('5-6 表示周末'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.confirm))],
      ),
    );
  }

  /// 计算下次执行时间
  String? _calculateNextExecutionTime(String expression) {
    try {
      final parts = expression.trim().split(RegExp(r'\s+'));
      if (parts.length != 5) {
        return null;
      }

      final minute = parts[0];
      final hour = parts[1];
      final day = parts[2];
      final month = parts[3];
      final weekday = parts[4];

      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, now.hour, now.minute);

      // 最多查找未来一年
      final maxDate = DateTime(now.year + 1, now.month, now.day);

      while (next.isBefore(maxDate)) {
        // 检查月份
        if (!_matchesCronField(month, next.month, 1, 12)) {
          next = DateTime(next.year, next.month + 1, 1, 0, 0);
          continue;
        }

        // 检查日期
        if (!_matchesCronField(day, next.day, 1, 31)) {
          next = next.add(const Duration(days: 1));
          next = DateTime(next.year, next.month, next.day, 0, 0);
          continue;
        }

        // 检查星期（0=周一, 6=周日）
        final dayOfWeek = (next.weekday - 1) % 7;
        if (!_matchesCronField(weekday, dayOfWeek, 0, 6)) {
          next = next.add(const Duration(days: 1));
          next = DateTime(next.year, next.month, next.day, 0, 0);
          continue;
        }

        // 检查小时
        if (!_matchesCronField(hour, next.hour, 0, 23)) {
          next = next.add(const Duration(hours: 1));
          next = DateTime(next.year, next.month, next.day, next.hour, 0);
          continue;
        }

        // 检查分钟
        if (!_matchesCronField(minute, next.minute, 0, 59)) {
          next = next.add(const Duration(minutes: 1));
          continue;
        }

        // 如果找到的时间是过去的时间，继续查找下一个
        if (next.isBefore(now)) {
          // 尝试下一个分钟
          next = next.add(const Duration(minutes: 1));
          continue;
        }

        // 格式化时间
        return _formatDateTime(next);
      }

      return null;
    } catch (e) {
      _logger.e("计算下次执行时间失败: $e");
      return null;
    }
  }

  /// 检查值是否匹配 cron 字段
  bool _matchesCronField(String field, int value, int min, int max) {
    if (field == '*') return true;

    // 处理步长，如 */15
    if (field.contains('/')) {
      final parts = field.split('/');
      if (parts[0] == '*') {
        final step = int.tryParse(parts[1]);
        if (step == null) return false;
        return value % step == 0;
      }
    }

    // 处理范围，如 0-4
    if (field.contains('-')) {
      final parts = field.split('-');
      if (parts.length == 2) {
        final start = int.tryParse(parts[0]);
        final end = int.tryParse(parts[1]);
        if (start != null && end != null) {
          return value >= start && value <= end;
        }
      }
    }

    // 处理列表，如 1,3,5
    if (field.contains(',')) {
      final values = field.split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
      return values.contains(value);
    }

    // 处理单个值
    final fieldValue = int.tryParse(field);
    if (fieldValue != null) {
      return fieldValue == value;
    }

    return false;
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final daysDiff = targetDate.difference(today).inDays;

    String dateStr;
    if (daysDiff == 0) {
      dateStr = '今天';
    } else if (daysDiff == 1) {
      dateStr = '明天';
    } else if (daysDiff == 2) {
      dateStr = '后天';
    } else {
      dateStr = '${dateTime.month}月${dateTime.day}日';
    }

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$dateStr $hour:$minute';
  }

  Widget _buildHelpItem(String expression, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(expression, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(description)),
        ],
      ),
    );
  }
}
