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

/// 定时任务列表页面
class CronTaskListPage extends ConsumerWidget {
  const CronTaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(cronTaskListProvider);
    final devicesAsync = ref.watch(playerDevicesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(S.scheduledTasks),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              context.push('/cron-task/edit', extra: {'task': null, 'index': -1});
            },
            tooltip: S.addScheduledTask,
          ),
        ],
      ),
      body: tasksAsync.when(
        data: (tasks) {
          return devicesAsync.when(
            data: (devices) {
              if (tasks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 64,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        S.emptyScheduledTasks,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(cronTaskListProvider.notifier).refresh();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _TaskCard(
                      task: task,
                      index: index,
                      devices: devices,
                      onTap: () {
                        context.push('/cron-task/edit', extra: {'task': task, 'index': index});
                      },
                      onDelete: () => _showDeleteDialog(context, ref, index),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 64,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          S.emptyScheduledTasks,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(cronTaskListProvider.notifier).refresh();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _TaskCard(
                          task: task,
                          index: index,
                          devices: {},
                          onTap: () {
                            context.push('/cron-task/edit', extra: {'task': task, 'index': index});
                          },
                          onDelete: () => _showDeleteDialog(context, ref, index),
                        );
                      },
                    ),
                  ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          _logger.e("加载定时任务失败: $error");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                Text('${S.error}: $error', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(cronTaskListProvider.notifier).refresh();
                  },
                  child: const Text(S.retry),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.delete),
        content: const Text(S.deleteTaskConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(cronTaskListProvider.notifier).deleteTask(index);
                if (context.mounted) {
                  SnackBarUtils.showMessage(context, S.taskDeleted);
                }
              } catch (e) {
                _logger.e("删除定时任务失败: $e");
                if (context.mounted) {
                  SnackBarUtils.showError(context, '${S.taskDeleteFailed}: $e');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
  }
}

/// 任务卡片
class _TaskCard extends StatelessWidget {
  final CronTask task;
  final int index;
  final Map<String, Device> devices;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.index,
    required this.devices,
    required this.onTap,
    required this.onDelete,
  });

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

  IconData _getTaskTypeIcon(CronTaskType type) {
    switch (type) {
      case CronTaskType.stop:
        return Icons.power_settings_new_rounded;
      case CronTaskType.play:
        return Icons.play_circle_rounded;
      case CronTaskType.playMusicList:
        return Icons.queue_music_rounded;
      case CronTaskType.tts:
        return Icons.record_voice_over_rounded;
      case CronTaskType.refreshMusicList:
        return Icons.refresh_rounded;
      case CronTaskType.setVolume:
        return Icons.volume_up_rounded;
      case CronTaskType.setPlayType:
        return Icons.shuffle_rounded;
      case CronTaskType.setPullAsk:
        return Icons.settings_voice_rounded;
      case CronTaskType.reinit:
        return Icons.restart_alt_rounded;
      case CronTaskType.playMusicTmpList:
        return Icons.playlist_play_rounded;
    }
  }

  String _getDeviceDisplayName(String did) {
    final device = devices[did];
    if (device != null && device.name != null && device.name!.isNotEmpty) {
      return device.name!;
    }
    return did;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_getTaskTypeIcon(task.type), color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTaskTypeName(task.type),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (task.arg1 != null && task.arg1!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${task.arg1}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: AppColors.error,
                    onPressed: onDelete,
                    tooltip: S.delete,
                  ),
                ],
              ),
              if (task.did != null && task.did!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${S.deviceName}: ${_getDeviceDisplayName(task.did!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${S.cronExpression}: ${task.expression}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
