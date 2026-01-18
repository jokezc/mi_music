import 'package:flutter/material.dart';

/// 应用颜色常量
/// 主色调：渐变紫蓝色
/// 强调色：玫瑰粉
class AppColors {
  AppColors._();

  // 主色调 - 渐变紫蓝色
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  
  // 次要色 - 紫色渐变终点
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color secondaryLight = Color(0xFFA78BFA);
  static const Color secondaryDark = Color(0xFF7C3AED);
  
  // 强调色 - 玫瑰粉
  static const Color accent = Color(0xFFF472B6);
  static const Color accentLight = Color(0xFFF9A8D4);
  static const Color accentDark = Color(0xFFEC4899);

  // 渐变色
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // 浅色模式颜色
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextHint = Color(0xFF94A3B8);
  static const Color lightDivider = Color(0xFFE2E8F0);
  static const Color lightBorder = Color(0xFFCBD5E1);

  // 深色模式颜色
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextHint = Color(0xFF64748B);
  static const Color darkDivider = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF475569);

  // 状态颜色
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // 播放器特殊颜色
  static const Color playerOverlay = Color(0xB30F172A); // 70% 透明深色
  static const Color miniPlayerBackground = Color(0xFF1E293B);
}

