import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/breakpoints.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/presentation/pages/settings/sections/about_section.dart';
import 'package:mi_music/presentation/widgets/responsive_content.dart';

/// 关于页面
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.about),
      ),
      body: const ResponsiveContent(
        maxWidth: Breakpoints.maxFormWidth,
        child: AboutSection(),
      ),
    );
  }
}

