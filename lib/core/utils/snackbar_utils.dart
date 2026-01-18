import 'package:flutter/material.dart';
import 'package:mi_music/core/theme/app_colors.dart';

/// SnackBar 辅助类
class SnackBarUtils {
  SnackBarUtils._();

  /// 显示成功消息
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.check_circle,
      backgroundColor: AppColors.success,
    );
  }

  /// 显示错误消息
  static void showError(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.error,
      backgroundColor: AppColors.error,
    );
  }

  /// 显示警告消息
  static void showWarning(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.warning,
      backgroundColor: AppColors.warning,
    );
  }

  /// 显示普通消息
  static void showInfo(BuildContext context, String message) {
    _showSnackBar(
      context,
      message: message,
      icon: Icons.info,
      backgroundColor: AppColors.info,
    );
  }

  /// 通用 SnackBar
  static void _showSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // 显示在顶部：只设置左右和顶部边距，底部不设置
        margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2), // 缩短为2秒
      ),
    );
  }

  /// 显示简单的消息（无图标，显示在顶部）
  static void showMessage(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // 显示在顶部
        margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  /// 显示加载中的 SnackBar（可手动关闭）
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoading(
    BuildContext context,
    String message,
  ) {
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // 加载中的也显示在顶部
        margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(hours: 1), // 需要手动关闭
      ),
    );
  }
}
