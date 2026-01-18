import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/presentation/pages/settings/sections/directory_section.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cron_task_provider.g.dart';

final _logger = Logger();

/// 定时任务列表Provider
@riverpod
class CronTaskList extends _$CronTaskList {
  @override
  Future<List<CronTask>> build() async {
    return _loadTasks();
  }

  Future<List<CronTask>> _loadTasks() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final setting = await apiClient.getSetting(false);
      final crontabJson = setting.crontabJson;

      if (crontabJson == null || crontabJson.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(crontabJson);
      return jsonList.map((json) => CronTask.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      _logger.e("加载定时任务失败: $e");
      return [];
    }
  }

  /// 刷新任务列表
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadTasks());
  }

  /// 保存任务列表
  Future<void> saveTasks(List<CronTask> tasks) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final currentSetting = await apiClient.getSetting(false);

      final tasksJson = json.encode(tasks.map((task) => task.toJson()).toList());
      final updatedSetting = currentSetting.copyWith(crontabJson: tasksJson);

      await apiClient.saveSetting(updatedSetting);
      await refresh();
    } catch (e) {
      _logger.e("保存定时任务失败: $e");
      rethrow;
    }
  }

  /// 添加任务
  Future<void> addTask(CronTask task) async {
    final currentTasks = state.value ?? [];
    final updatedTasks = [...currentTasks, task];
    await saveTasks(updatedTasks);
  }

  /// 更新任务
  Future<void> updateTask(int index, CronTask task) async {
    final currentTasks = state.value ?? [];
    if (index < 0 || index >= currentTasks.length) {
      throw RangeError('索引超出范围');
    }
    final updatedTasks = List<CronTask>.from(currentTasks);
    updatedTasks[index] = task;
    await saveTasks(updatedTasks);
  }

  /// 删除任务
  Future<void> deleteTask(int index) async {
    final currentTasks = state.value ?? [];
    if (index < 0 || index >= currentTasks.length) {
      throw RangeError('索引超出范围');
    }
    final updatedTasks = List<CronTask>.from(currentTasks);
    updatedTasks.removeAt(index);
    await saveTasks(updatedTasks);
  }
}
