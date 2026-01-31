import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

final _logger = Logger();

/// 权限工具类
class PermissionUtils {
  /// 申请必要的初始权限（包括通知、网络相关等）
  static Future<void> requestInitialPermissions() async {
    /*
    // 1. 请求通知权限（Android 13+ 需要用于前台服务显示，对音乐App很重要）
    // 只有在未授权时才请求，避免不必要的调用
    final notificationStatus = await ph.Permission.notification.status;
    if (!notificationStatus.isGranted) {
      await ph.Permission.notification.request();
    }

    // 2. 如果是 Android 13+，请求附近设备权限（可能有助于本地网络发现）
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // 虽然普通 HTTP 请求不需要此权限，但在某些设备发现场景可能需要
        // 如果不需要显式发现，可以注释掉
        // await ph.Permission.nearbyWifiDevices.request();
      }
    }
    */
    // 3. iOS 网络权限触发逻辑
    if (Platform.isIOS) {
      await _triggerIOSNetworkPermissions();
    }
  }

  /// 触发 iOS 网络权限（无线数据 + 本地网络）
  static Future<void> _triggerIOSNetworkPermissions() async {
    // 1. 触发“无线数据”权限（针对国行 iOS）
    // 通过发起一个简单的网络请求（DNS查询）来触发系统弹窗
    try {
      await InternetAddress.lookup('www.apple.com');
    } catch (e) {
      // 忽略错误，目的仅是触发系统检测
    }

    // 2. 触发“本地网络”权限
    // 只有在访问局域网设备时才会触发。通过发送 UDP 广播可以有效触发此权限。
    try {
      // 绑定一个随机端口
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      // 发送一个空数据包到广播地址
      socket.send([], InternetAddress('255.255.255.255'), 4567);
      socket.close();
    } catch (e) {
      // 忽略错误
    }
  }

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

