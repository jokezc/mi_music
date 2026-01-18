import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';

part 'theme_provider.g.dart';

/// 主题模式枚举
enum AppThemeMode {
  system, // 跟随系统
  light,  // 浅色模式
  dark,   // 深色模式
}

/// 主题状态管理
@riverpod
class ThemeController extends _$ThemeController {
  @override
  AppThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final modeIndex = prefs.getInt(SharedPrefKeys.themeMode) ?? 0;
    return AppThemeMode.values[modeIndex.clamp(0, AppThemeMode.values.length - 1)];
  }

  /// 设置主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(SharedPrefKeys.themeMode, mode.index);
    state = mode;
  }

  /// 切换主题（循环切换：系统 -> 浅色 -> 深色 -> 系统）
  Future<void> toggleTheme() async {
    final nextIndex = (state.index + 1) % AppThemeMode.values.length;
    await setThemeMode(AppThemeMode.values[nextIndex]);
  }

  /// 获取实际的 ThemeMode
  ThemeMode get themeMode {
    switch (state) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }
}

/// 主题模式名称
extension AppThemeModeExtension on AppThemeMode {
  String get displayName {
    switch (this) {
      case AppThemeMode.system:
        return '跟随系统';
      case AppThemeMode.light:
        return '浅色模式';
      case AppThemeMode.dark:
        return '深色模式';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
    }
  }
}

