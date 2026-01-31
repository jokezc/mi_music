import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/presentation/pages/settings/sections/directory_section.dart';

final _logger = Logger();

/// 供登录页等调用的弹窗：服务地址与当前连接不一致时让用户选择「跳转服务配置」或「快速修改」。
/// 返回后调用方再决定是否跳转（如登录页可再 context.go('/')）。
Future<void> showHostPortMismatchDialog(
  BuildContext context,
  WidgetRef ref,
  HostPortMismatch mismatch,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('服务地址与当前连接不一致'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '服务端配置的访问地址与您当前连接的地址不一致，可能导致音乐无法播放或展示。',
              ),
              const SizedBox(height: 12),
              Text(
                '当前连接：${mismatch.connectionHost}:${mismatch.connectionPort}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '服务端配置：${mismatch.settingHostname}:${mismatch.settingPublicPort}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                '您可以选择：跳转到「服务配置」自行修改，或由应用根据当前连接地址快速更新服务端配置。',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/settings?section=service');
            },
            child: const Text('跳转到服务配置'),
          ),
          FilledButton(
            onPressed: () => _applyQuickFix(dialogContext, ref, mismatch),
            child: const Text('快速修改'),
          ),
        ],
      );
    },
  );
}

Future<void> _applyQuickFix(
  BuildContext dialogContext,
  WidgetRef ref,
  HostPortMismatch mismatch,
) async {
  try {
    final client = ref.read(apiClientProvider);
    final setting = await client.getSetting(false);
    final updated = setting.copyWith(
      hostname: mismatch.connectionHostnameWithScheme,
      publicPort: mismatch.connectionPort,
    );
    await client.saveSetting(updated);
    if (!dialogContext.mounted) return;
    Navigator.of(dialogContext).pop();
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      const SnackBar(
        content: Text('已按当前连接地址更新服务端配置'),
        backgroundColor: AppColors.success,
      ),
    );
  } catch (e) {
    _logger.e('快速修改 host/port 失败: $e');
    if (!dialogContext.mounted) return;
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(
        content: Text('更新失败: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
