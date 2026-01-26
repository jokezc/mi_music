import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/services/umeng_service.dart';
import 'package:url_launcher/url_launcher.dart';

Future<Map<String, dynamic>> fetchUpdateInfo() async {
  try {
    final dio = Dio();
    final response = await dio.get('https://api.github.com/repos/jokezc/mi_music/releases/latest');
    if (response.statusCode == 200) {
      final data = response.data;
      final latestVersion = data['tag_name'] ?? '';
      final releaseUrl = data['html_url'] ?? 'https://github.com/jokezc/mi_music/releases';
      final releaseNotes = data['body'] ?? '';
      return {
        'hasUpdate': latestVersion.isNotEmpty && latestVersion != BaseConstants.currentVersion,
        'latestVersion': latestVersion,
        'releaseUrl': releaseUrl,
        'releaseNotes': releaseNotes,
      };
    }
    return {'hasUpdate': false, 'error': 'Status code: ${response.statusCode}'};
  } catch (e) {
    return {'hasUpdate': false, 'error': e.toString()};
  }
}

final updateCheckProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return fetchUpdateInfo();
});

Future<void> _showUpdateDialog(
  BuildContext context,
  String latestVersion,
  String releaseUrl,
  String releaseNotes,
) async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('发现新版本'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本: ${BaseConstants.currentVersion}'),
            Text('最新版本: $latestVersion'),
            if (releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(releaseNotes),
            ],
            const SizedBox(height: 16),
            const Text('是否前往下载新版本？'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop();
            if (await canLaunchUrl(Uri.parse(releaseUrl))) {
              await launchUrl(Uri.parse(releaseUrl), mode: LaunchMode.externalApplication);
            }
          },
          child: const Text('前往下载'),
        ),
      ],
    ),
  );
}

/// 关于 Section
class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(updateCheckProvider, (previous, next) {
      next.whenData((data) {
        if (data['hasUpdate'] == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              _showUpdateDialog(
                context,
                data['latestVersion'] as String,
                data['releaseUrl'] as String,
                data['releaseNotes'] as String,
              );
            }
          });
        }
      });
    });

    final updateAsync = ref.watch(updateCheckProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_android_rounded),
                  title: const Text(S.appVersion),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(BaseConstants.currentVersion),
                      if (updateAsync.value?['hasUpdate'] == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Chip(
                            label: const Text('有新版本', style: TextStyle(fontSize: 10)),
                            backgroundColor: Colors.red,
                            labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_rounded),
                  title: const Text(S.backendVersion),
                  trailing: FutureBuilder(
                    future: ref.read(apiClientProvider).getVersion(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      if (snap.hasError) {
                        return const Text('-');
                      }
                      return Text(snap.data?.version ?? '-');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('App 开源地址'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () async {
                    final url = Uri.parse('https://github.com/jokezc/mi_music');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dns_rounded),
                  title: const Text('后端服务'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () async {
                    final url = Uri.parse('https://github.com/hanxi/xiaomusic');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.update_rounded),
                  title: const Text('检查更新'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _checkForUpdateAndShowDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded),
                  title: const Text(S.privacyPolicy),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    context.push('/privacy-policy');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: const Text(S.disclaimer),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    context.push('/disclaimer');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.article_rounded),
                  title: const Text(S.openSourceLicense),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: S.appName,
                      applicationVersion: BaseConstants.currentVersion,
                      applicationIcon: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.music_note_rounded, size: 36, color: Colors.white),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report_rounded, color: Colors.orange),
                  title: const Text('测试错误上报'),
                  subtitle: const Text('主动上报一个测试错误，用于验证友盟错误监听功能'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _testErrorReport(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.favorite_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      const Text('支持我们', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.favorite_rounded, color: Colors.red),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '感谢您对风花雪乐的支持！',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('微信支付', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset('assets/wx.jpg', width: 120, height: 120, fit: BoxFit.cover),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('支付宝', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset('assets/zfb.jpg', width: 120, height: 120, fit: BoxFit.cover),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '您的支持是我们前进的动力！',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '风花雪乐 是一个基于小米 AI 音箱的音乐播放控制应用，支持远程控制和本地播放功能。',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            '© 2026 风花雪乐 Flutter App',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdateAndShowDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('正在检查更新...')]),
      ),
    );

    Map<String, dynamic> data;
    try {
      data = await fetchUpdateInfo();
    } catch (e) {
      data = {'error': e.toString(), 'hasUpdate': false};
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }

    if (context.mounted) {
      if (data['hasUpdate'] == true) {
        _showUpdateDialog(
          context,
          data['latestVersion'] as String,
          data['releaseUrl'] as String,
          data['releaseNotes'] as String,
        );
      } else if (data['error'] != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('检查更新'),
            content: Text('检查更新失败: ${data['error']}'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('确定'))],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('检查更新'),
            content: const Text('当前已是最新版本！'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('确定'))],
          ),
        );
      }
    }
  }

  /// 测试错误上报
  void _testErrorReport(BuildContext context) {
    // 显示确认对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('测试错误上报'),
        content: const Text('这将主动上报一个测试错误到友盟，用于验证错误监听功能是否正常工作。\n\n确定要继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _doTestErrorReport(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 执行测试错误上报
  void _doTestErrorReport(BuildContext context) {
    try {
      // 检查友盟是否已初始化
      if (!UmengService.isEnabled) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('测试错误上报'),
              content: const Text('友盟SDK未初始化，无法上报错误。\n\n请确保：\n1. 已同意隐私协议\n2. 已配置友盟AppKey'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 创建一个测试错误，使用当前的堆栈跟踪
      final testError = Exception('这是一个测试错误，用于验证友盟错误上报功能');
      final testStackTrace = StackTrace.current;

      // 上报错误，附带一些测试上下文信息
      UmengService.reportError(
        testError,
        testStackTrace,
        context: {
          'test_type': 'manual_test',
          'test_purpose': '验证友盟错误上报功能',
          'test_timestamp': DateTime.now().toIso8601String(),
          'test_location': 'AboutSection',
        },
      );

      // 显示成功提示
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('测试错误上报'),
            content: const Text('测试错误已成功上报到友盟！\n\n您可以在友盟U-APM后台查看错误详情。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 如果上报过程中出错，显示错误提示
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('测试错误上报'),
            content: Text('上报测试错误时发生异常：$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }
}
