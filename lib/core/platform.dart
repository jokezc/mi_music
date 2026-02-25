import 'package:flutter/foundation.dart';

/// 应用运行平台判断（仅用 foundation，不依赖 dart:io，兼容 Web 与测试）
///
/// 多端兼容常见做法：
/// - 平台分支集中在此处，业务只读 [isDesktop]/[isWindows] 等，避免各处重复写 defaultTargetPlatform
/// - 需整文件替换时再用 conditional imports（export 'stub.dart' if (dart.library.io) 'io.dart'）
/// - 见 https://docs.flutter.dev/platform-integration/platform-channels
class AppPlatform {
  AppPlatform._();

  /// 是否为桌面端（Windows / macOS / Linux），用于布局、导航等
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// 是否为 Windows（当前使用 just_audio_media_kit，需 resume 时的 workaround）
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// 是否为 Linux（若后续启用 just_audio_media_kit，可在此扩展 workaround）
  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
}
