import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/presentation/pages/settings/sections/appearance_section.dart';

/// 外观设置页面
class AppearancePage extends ConsumerWidget {
  const AppearancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.appearanceSettings),
      ),
      body: const AppearanceSection(),
    );
  }
}

