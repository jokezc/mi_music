import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/presentation/pages/settings/sections/client_section.dart';

/// 软件设置页面（只包含客户端设置）
class ClientSettingsPage extends ConsumerWidget {
  const ClientSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.softwareSettings),
      ),
      body: const ClientSection(),
    );
  }
}

