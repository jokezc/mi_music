import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:umeng_common_sdk/umeng_common_sdk.dart';
import 'package:umeng_apm_sdk/umeng_apm_sdk.dart';

final _logger = Logger();

/// 友盟配置信息
class _UmengConfig {
  static String? androidAppKey;
  static String? iosAppKey;
  static String channel = '';

  /// 从原生代码读取配置
  /// 
  /// 如果配置文件不存在或 AppKey 为空，会静默处理（这是可选功能）
  static Future<void> loadConfig() async {
    const platform = MethodChannel('cn.jokeo.mi_music/umeng_config');
    try {
      final result = await platform.invokeMethod<Map<Object?, Object?>>('getUmengConfig');
      if (result != null) {
        final appKey = result['appKey']?.toString() ?? '';
        channel = result['channel']?.toString() ?? '';
        
        if (Platform.isAndroid) {
          androidAppKey = appKey;
        } else if (Platform.isIOS) {
          iosAppKey = appKey;
        }
        
        // 只有在成功读取到非空 AppKey 时才输出日志
        if (appKey.isNotEmpty) {
          _logger.i('友盟配置加载成功: AppKey=${appKey.substring(0, appKey.length > 8 ? 8 : appKey.length)}..., Channel=$channel');
        }
        // AppKey 为空时不输出日志（静默处理，因为这是可选功能）
      }
    } catch (e) {
      // 配置读取失败时静默处理，不输出错误日志（因为这是可选功能）
      // 只在调试模式下输出详细信息
      if (kDebugMode) {
        _logger.d('读取友盟配置失败（可选功能，不影响应用运行）: $e');
      }
      // 确保设置为空值，后续初始化会跳过
      if (Platform.isAndroid) {
        androidAppKey = '';
      } else if (Platform.isIOS) {
        iosAppKey = '';
      }
    }
  }
}

/// 友盟统计和错误上报服务
/// 
/// **可选功能说明**：
/// - 友盟功能是可选的，如果未配置 AppKey，所有方法会静默跳过，不影响应用运行
/// - 配置方式：
///   - Android: 在 `android/app/src/main/assets/umeng_config.properties` 中配置 `umeng.appkey`
///   - iOS: 在 `ios/Runner/umeng_config.plist` 中配置 `UMAppKey`
/// - 配置文件模板：参考 `umeng_config.properties.example` 和 `umeng_config.plist.example`
class UmengService {
  static bool _initialized = false;
  static bool _configChecked = false; // 标记是否已检查过配置
  static String? _frontendVersion;
  static String? _backendVersion;
  static UmengApmSdk? _apmSdk; // U-APM SDK 实例

  /// 检查友盟功能是否已启用
  /// 返回 true 表示已配置 AppKey 并成功初始化
  static bool get isEnabled => _initialized;

  /// 初始化友盟SDK
  /// 
  /// **重要：此方法必须在用户同意隐私协议后调用，符合隐私合规要求**
  /// 
  /// 合规说明：
  /// 1. 只有在用户明确同意隐私协议后，才会调用此方法初始化SDK
  /// 2. 初始化后，友盟SDK才会开始收集设备信息和使用统计
  /// 3. 延迟初始化本身就是通知友盟用户已同意的方式
  /// 
  /// **可选功能**：
  /// - 如果未配置 AppKey，会静默跳过初始化，不影响应用运行
  /// - 这是开源项目的正常行为，开发者可以选择是否使用友盟功能
  /// 
  /// 需要在应用启动时调用，在WidgetsFlutterBinding.ensureInitialized()之后
  static Future<void> init() async {
    if (_initialized) {
      return;
    }

    if (_configChecked) {
      // 已经检查过配置，如果未初始化说明未配置 AppKey，静默跳过
      return;
    }

    _configChecked = true;

    try {
      // 加载版本信息（即使不使用友盟，版本信息也可能用于其他用途）
      await _loadVersions();

      // 从配置文件加载友盟配置
      await _UmengConfig.loadConfig();

      // 根据平台选择AppKey
      final appKey = Platform.isAndroid ? _UmengConfig.androidAppKey : _UmengConfig.iosAppKey;
      
      // 如果未配置 AppKey，静默跳过（这是可选功能，不需要警告）
      if (appKey == null || appKey.isEmpty) {
        _logger.d('友盟功能未启用：未配置 AppKey（这是可选的，不影响应用运行）');
        return;
      }

      _logger.i('用户已同意隐私协议，开始初始化友盟SDK（符合隐私合规要求）');

      // 初始化友盟统计SDK
      // 注意：只有在用户同意隐私协议后才调用此方法，这是通知友盟用户已同意的方式
      UmengCommonSdk.initCommon(
        _UmengConfig.androidAppKey ?? '',
        _UmengConfig.iosAppKey ?? '',
        _UmengConfig.channel.isEmpty ? 'Umeng' : _UmengConfig.channel,
      );
      
      // 设置页面统计为手动模式
      UmengCommonSdk.setPageCollectionModeManual();

      // 初始化友盟U-APM SDK（用于错误上报和性能监控）
      // 必须在 UmengCommonSdk.initCommon 之后初始化
      // 创建 U-APM SDK 实例，这会自动初始化 ExceptionTrace
      _apmSdk = UmengApmSdk(
        name: '风花雪乐', // 应用名称
        bver: _frontendVersion ?? BaseConstants.currentVersion, // 使用版本号
        enableLog: kDebugMode, // 调试模式下开启日志
      );
      // 调用 init 方法初始化（不传入 appRunner，因为我们已经在 main 中调用了 runApp）
      _apmSdk!.init();
      _logger.i('友盟U-APM SDK初始化成功');

      // 使用设备ID作为用户标识（保护隐私，不泄露登录信息）
      await _setDeviceIdAsUserId();

      _initialized = true;
      _logger.i('友盟SDK初始化成功 (平台: ${Platform.operatingSystem}, AppKey: ${appKey.substring(0, appKey.length > 8 ? 8 : appKey.length)}...)');
      _logger.i('版本信息: 前端=$_frontendVersion, 后端=$_backendVersion');
    } catch (e, stackTrace) {
      // 初始化失败时记录错误，但不影响应用运行
      _logger.w('友盟SDK初始化失败（不影响应用运行）: $e');
      // 只在调试模式下输出详细堆栈
      if (kDebugMode) {
        _logger.e('堆栈: $stackTrace');
      }
    }
  }

  /// 加载版本信息
  static Future<void> _loadVersions() async {
    try {
      // 获取前端版本（直接使用常量，与 pubspec.yaml 保持一致）
      _frontendVersion = BaseConstants.apkVersion;

      // 获取后端版本（从 SharedPreferences）
      final prefs = await SharedPreferences.getInstance();
      _backendVersion = prefs.getString(SharedPrefKeys.backendVersion);
    } catch (e) {
      _logger.w('加载版本信息失败: $e');
    }
  }

  /// 更新后端版本
  static Future<void> updateBackendVersion(String version) async {
    if (_backendVersion == version) return;
    
    _backendVersion = version;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(SharedPrefKeys.backendVersion, version);
      _logger.i('后端版本已更新: $version');
    } catch (e) {
      _logger.w('保存后端版本失败: $e');
    }
  }

  /// 获取设备唯一标识符并设置为用户ID
  /// 使用设备ID而不是登录信息，保护用户隐私
  static Future<void> _setDeviceIdAsUserId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      String? deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Android ID 是设备唯一标识符，不会泄露用户隐私
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // identifierForVendor 是应用级别的唯一标识符
        deviceId = iosInfo.identifierForVendor;
      }

      if (deviceId != null && deviceId.isNotEmpty) {
        // 使用设备ID作为用户标识，不包含任何登录信息
        UmengCommonSdk.onProfileSignIn(deviceId);
        _logger.i('已设置设备ID作为用户标识: ${deviceId.substring(0, 8)}...');
      } else {
        _logger.w('无法获取设备ID，将使用友盟默认的用户标识');
      }
    } catch (e) {
      _logger.w('获取设备ID失败: $e，将使用友盟默认的用户标识');
      // 获取设备ID失败不影响统计功能，友盟会自动生成匿名ID
    }
  }

  /// 页面统计：页面开始
  /// [pageName] 页面名称
  static void onPageStart(String pageName) {
    if (!_initialized) return;
    try {
      UmengCommonSdk.onPageStart(pageName);
    } catch (e) {
      _logger.w('页面统计开始失败: $e');
    }
  }

  /// 页面统计：页面结束
  /// [pageName] 页面名称
  static void onPageEnd(String pageName) {
    if (!_initialized) return;
    try {
      UmengCommonSdk.onPageEnd(pageName);
    } catch (e) {
      _logger.w('页面统计结束失败: $e');
    }
  }

  /// 事件统计
  /// [eventId] 事件ID
  /// [properties] 事件属性（可选）
  static void onEvent(String eventId, {Map<String, dynamic>? properties}) {
    if (!_initialized) return;
    try {
      if (properties != null && properties.isNotEmpty) {
        UmengCommonSdk.onEvent(eventId, properties);
      } else {
        UmengCommonSdk.onEvent(eventId, {});
      }
    } catch (e) {
      _logger.w('事件统计失败: $e');
    }
  }

  /// 上报自定义错误
  /// [error] 错误对象
  /// [stackTrace] 堆栈信息
  /// [context] 错误上下文信息（可选）
  static void reportError(
    Object error,
    StackTrace stackTrace, {
    Map<String, String>? context,
  }) {
    if (!_initialized) return;
    try {
      // 添加版本信息到上下文
      final extra = Map<String, String>.from(context ?? {});
      if (_frontendVersion != null) extra['frontend_version'] = _frontendVersion!;
      if (_backendVersion != null) extra['backend_version'] = _backendVersion!;

      // 使用U-APM上报错误
      ExceptionTrace.captureException(
        exception: error is Exception ? error : Exception(error.toString()),
        extra: extra,
      );
    } catch (e) {
      _logger.w('错误上报失败: $e');
    }
  }

  /// 上报自定义异常（字符串形式）
  /// [errorMessage] 错误消息
  /// [stackTrace] 堆栈信息
  /// [context] 错误上下文信息（可选）
  static void reportErrorString(
    String errorMessage,
    String stackTrace, {
    Map<String, String>? context,
  }) {
    if (!_initialized) return;
    try {
      // 添加版本信息到上下文
      final extra = Map<String, String>.from(context ?? {});
      if (_frontendVersion != null) extra['frontend_version'] = _frontendVersion!;
      if (_backendVersion != null) extra['backend_version'] = _backendVersion!;

      // 使用U-APM上报错误
      ExceptionTrace.captureException(
        exception: Exception(errorMessage),
        extra: extra,
      );
    } catch (e) {
      _logger.w('错误上报失败: $e');
    }
  }

  /// 设置用户ID（已废弃，使用设备ID自动设置）
  /// 保留此方法以保持兼容性，但不会使用登录信息
  @Deprecated('使用设备ID自动设置，不需要手动调用')
  static void setUserId(String userId) {
    _logger.w('setUserId已废弃，用户ID由设备ID自动设置');
  }

  /// 清除用户ID（已废弃，设备ID不需要清除）
  /// 保留此方法以保持兼容性
  @Deprecated('设备ID不需要清除，保留此方法以保持兼容性')
  static void clearUserId() {
    _logger.w('clearUserId已废弃，设备ID不需要清除');
  }

  /// 通知友盟用户已同意隐私协议
  /// 
  /// 此方法用于明确通知友盟SDK用户已同意隐私协议
  /// 通过事件统计的方式记录用户同意行为，便于在友盟后台查看
  /// 
  /// 调用时机：在用户点击"同意并继续"后，初始化SDK之前或之后调用
  /// 
  /// **注意**：如果友盟功能未启用（未配置 AppKey），此方法会静默跳过
  static void notifyPrivacyAgreementAccepted() {
    if (!_initialized) {
      // 静默跳过，不输出日志（因为这是可选功能）
      return;
    }

    try {
      // 通过事件统计记录用户同意隐私协议的行为
      // 事件ID: privacy_agreement_accepted
      // 事件属性: timestamp (同意时间戳)
      UmengCommonSdk.onEvent(
        'privacy_agreement_accepted',
        {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'version': '1.0', // 隐私协议版本，可根据实际情况更新
        },
      );
      _logger.i('已通知友盟：用户已同意隐私协议');
    } catch (e) {
      _logger.w('通知友盟隐私协议同意状态失败: $e');
    }
  }
}
