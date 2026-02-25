import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/globals.dart';
import 'package:mi_music/core/theme/app_theme.dart';
import 'package:mi_music/core/utils/permission_utils.dart';
import 'package:mi_music/data/providers/cache_provider.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';
import 'package:mi_music/data/providers/theme_provider.dart';
import 'package:mi_music/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _mainLogger = Logger();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // just_audio 官方仅支持 Android/iOS/macOS/Web；Windows 需通过 just_audio_media_kit 启用（见 https://pub.dev/packages/just_audio#windows）
  JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
  final sharedPrefs = await SharedPreferences.getInstance();

  final app = ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
    child: const MyApp(),
  );

  // 全平台包 zone：just_audio 在部分场景（如 Windows 用 media_kit 时恢复前台、切换歌单）会收到 currentIndex=-1，内部用 -1 访问列表导致 RangeError，此处统一兜底避免崩溃
  runZonedGuarded(() {
    runApp(app);
  }, (Object error, StackTrace stack) {
    if (error is RangeError &&
        error.message.contains('Not in inclusive range') &&
        error.message.contains('-1')) {
      _mainLogger.w('已忽略 just_audio currentIndex=-1 导致的 RangeError（常见于切换歌单/恢复前台）');
      return;
    }
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  });
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
    // 申请初始权限（通知、网络等）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionUtils.requestInitialPermissions();
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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
