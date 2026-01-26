import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/shared_pref_keys.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/globals.dart';
import 'package:mi_music/core/theme/app_theme.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';
import 'package:mi_music/data/providers/theme_provider.dart';
import 'package:mi_music/data/services/umeng_service.dart';
import 'package:mi_music/presentation/widgets/privacy_agreement_dialog.dart';
import 'package:mi_music/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _logger = Logger();

Future<void> main() async {
  // 确保Flutter绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPrefs = await SharedPreferences.getInstance();

  // 检查用户是否已同意隐私协议
  final hasAcceptedPrivacy = sharedPrefs.getBool(SharedPrefKeys.privacyAgreementAccepted) ?? false;
  
  _logger.i('隐私协议状态检查: hasAcceptedPrivacy = $hasAcceptedPrivacy');
  _logger.i('SharedPreferences中privacy_agreement_accepted的值: ${sharedPrefs.getBool(SharedPrefKeys.privacyAgreementAccepted)}');

  // 只有在用户同意后才初始化友盟SDK
  if (hasAcceptedPrivacy) {
    _logger.i('用户已同意隐私协议，初始化友盟SDK');
    await UmengService.init();
    // 配置全局异常捕获（只有在同意后才启用）
    _setupErrorHandling();
  } else {
    _logger.i('用户尚未同意隐私协议，暂不初始化统计SDK，将在首次打开时显示协议对话框');
  }

  // 使用runZonedGuarded包装runApp，捕获异步异常
  runZonedGuarded(
    () {
      runApp(ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
        child: MyApp(showPrivacyDialog: !hasAcceptedPrivacy),
      ));
    },
    (error, stackTrace) {
      // 捕获runZonedGuarded范围内的异步异常
      _logger.e('未捕获的异步异常: $error');
      _logger.e('堆栈: $stackTrace');
      // 只有在用户同意后才上报错误
      if (hasAcceptedPrivacy) {
        UmengService.reportError(error, stackTrace);
      }
    },
  );
}

/// 配置全局异常处理
/// 只有在用户同意隐私协议后才启用错误上报
void _setupErrorHandling() {
  // 捕获Flutter框架异常
  FlutterError.onError = (FlutterErrorDetails details) {
    // 在调试模式下，使用默认的错误处理（显示红色错误屏幕）
    FlutterError.presentError(details);
    
    // 上报错误到友盟（只有在用户同意后才上报）
    _logger.e('Flutter框架异常: ${details.exception}');
    _logger.e('堆栈: ${details.stack}');
    UmengService.reportError(
      details.exception,
      details.stack ?? StackTrace.current,
      context: {
        'library': details.library ?? 'unknown',
        'context': details.context?.toString() ?? '',
      },
    );
  };

  // 捕获Platform异常（Flutter 3.3+）
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _logger.e('Platform异常: $error');
    _logger.e('堆栈: $stackTrace');
    UmengService.reportError(error, stackTrace);
    return true; // 返回true表示已处理异常
  };
}

/// 初始化应用（在首屏加载时）
class AppInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const AppInitializer({super.key, required this.child});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  @override
  void initState() {
    super.initState();
    // 触发后端版本检查
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkBackendVersionProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 触发缓存初始化（不需要登录）
    ref.watch(initCacheProvider);

    // 提前初始化 AudioHandler，避免切换设备时动态初始化导致 bind 失败
    ref.watch(audioHandlerProvider);

    return widget.child;
  }
}

class MyApp extends ConsumerStatefulWidget {
  final bool showPrivacyDialog;

  const MyApp({super.key, this.showPrivacyDialog = false});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _dialogShown = false; // 标记对话框是否已显示，避免重复显示

  @override
  void initState() {
    super.initState();
    _logger.i('MyApp initState, showPrivacyDialog: ${widget.showPrivacyDialog}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在依赖变化后，如果路由已准备好，显示隐私协议对话框
    if (widget.showPrivacyDialog && !_dialogShown && mounted) {
      _dialogShown = true; // 标记已尝试显示，避免重复
      // 延迟一点时间，确保MaterialApp.router完全构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showPrivacyDialog();
          }
        });
      });
    }
  }

  Future<void> _showPrivacyDialog() async {
    if (!mounted) {
      _logger.w('组件已卸载，无法显示隐私协议对话框');
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    final router = ref.read(routerProvider);
    
    // 使用rootNavigatorKey来显示对话框，确保在正确的导航器上下文中
    final navigatorContext = router.routerDelegate.navigatorKey.currentContext;
    if (navigatorContext == null) {
      _logger.w('Navigator context未准备好，延迟显示隐私协议对话框');
      // 如果context还没准备好，再延迟一点
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showPrivacyDialog();
        }
      });
      return;
    }

    _logger.i('正在显示隐私协议对话框');

    await showDialog(
      context: navigatorContext,
      barrierDismissible: false, // 禁止点击外部关闭
      builder: (dialogContext) {
        // 保存 dialogContext 的引用，避免在异步操作后使用
        final navigator = Navigator.of(dialogContext);
        return PrivacyAgreementDialog(
          onAgree: () async {
            _logger.i('用户点击同意隐私协议');
            // 用户同意隐私协议
            await prefs.setBool(SharedPrefKeys.privacyAgreementAccepted, true);
            
            // 初始化友盟SDK
            await UmengService.init();
            
            // 通知友盟用户已同意隐私协议（通过事件统计同步）
            UmengService.notifyPrivacyAgreementAccepted();
            
            // 配置全局异常捕获
            _setupErrorHandling();
            
            // 使用保存的 navigator 引用，避免跨异步间隙使用 BuildContext
            if (mounted && navigator.canPop()) {
              navigator.pop();
              _logger.i('用户已同意隐私协议，友盟SDK已初始化并同步同意状态');
            }
          },
          onDisagree: () {
            _logger.i('用户点击不同意隐私协议');
            // 用户不同意，显示提示信息
            if (mounted) {
              navigator.pop();
              ScaffoldMessenger.of(navigatorContext).showSnackBar(
                const SnackBar(
                  content: Text('需要同意隐私协议才能使用应用'),
                  duration: Duration(seconds: 2),
                ),
              );
              // 延迟后重新显示对话框，让用户重新考虑
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  _dialogShown = false; // 重置标记，允许重新显示
                  _showPrivacyDialog();
                }
              });
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeController = ref.watch(themeControllerProvider.notifier);

    return AppInitializer(
      child: MaterialApp.router(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        title: S.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeController.themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'), // 中文简体
          Locale('en', 'US'), // 英文（作为后备）
        ],
        locale: const Locale('zh', 'CN'), // 默认使用中文
      ),
    );
  }
}
