import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

final _logger = Logger();

/// 权限工具类
class PermissionUtils {
  /// 检查并请求存储权限
  /// 返回 true 表示有权限，false 表示无权限
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      // iOS 或其他平台不需要权限
      return true;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+ (API 33+): 使用 READ_MEDIA_AUDIO
        final status = await ph.Permission.audio.request();
        return status.isGranted;
      } else if (sdkInt >= 29) {
        // Android 10-12 (API 29-32): 使用 WRITE_EXTERNAL_STORAGE
        // 注意：Android 10+ 即使有权限也无法直接访问公共目录
        // 但可以用于某些特殊场景
        final status = await ph.Permission.storage.request();
        return status.isGranted;
      } else {
        // Android 9 及以下: 使用 WRITE_EXTERNAL_STORAGE
        final status = await ph.Permission.storage.request();
        return status.isGranted;
      }
    } catch (e) {
      // 如果获取权限失败，返回 false
      _logger.e("请求存储权限失败: $e");
      return false;
    }
  }

  /// 检查存储权限状态（不请求）
  static Future<bool> checkStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 33) {
        final status = await ph.Permission.audio.status;
        return status.isGranted;
      } else {
        final status = await ph.Permission.storage.status;
        return status.isGranted;
      }
    } catch (e) {
      _logger.e("检查存储权限失败: $e");
      return false;
    }
  }

  /// 打开应用设置页面
  static Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }
}

