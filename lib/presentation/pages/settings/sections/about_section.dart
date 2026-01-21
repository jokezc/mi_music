import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:url_launcher/url_launcher.dart';


Future<Map<String, dynamic>> _checkForUpdate() async {
  try {
    final dio = Dio();
    final response = await dio.get('https://api.github.com/repos/jokezc/mi_music/releases/latest');
    if (response.statusCode == 200) {
      final data = response.data;
      final latestVersion = data['tag_name'] ?? '';
      final releaseUrl = data['html_url'] ?? 'https://github.com/jokezc/mi_music/releases';
      return {
        'hasUpdate': latestVersion.isNotEmpty && latestVersion != BaseConstants.currentVersion,
        'latestVersion': latestVersion,
        'releaseUrl': releaseUrl,
      };
    }
    return {'hasUpdate': false};
  } catch (e) {
    return {'hasUpdate': false};
  }
}

Future<void> _showUpdateDialog(BuildContext context, String latestVersion, String releaseUrl) async {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('发现新版本'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前版本: ${BaseConstants.currentVersion}'),
          Text('最新版本: $latestVersion'),
          const SizedBox(height: 8),
          const Text('是否前往下载新版本？'),
        ],
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
    return FutureBuilder(
      future: _checkForUpdate(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!['hasUpdate'] == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showUpdateDialog(
              context,
              snapshot.data!['latestVersion'] as String,
              snapshot.data!['releaseUrl'] as String,
            );
          });
        }

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
                          if (snapshot.hasData && snapshot.data!['hasUpdate'] == true)
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
                            return const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
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
      },
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

    try {
      final dio = Dio();
      final response = await dio.get('https://api.github.com/repos/jokezc/mi_music/releases/latest');
      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion = data['tag_name'] ?? '';
        final releaseUrl = data['html_url'] ?? 'https://github.com/jokezc/mi_music/releases';

        if (context.mounted) {
          Navigator.of(context).pop();
        }

        if (latestVersion.isNotEmpty && latestVersion != BaseConstants.currentVersion) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, releaseUrl);
          }
        } else {
          if (context.mounted) {
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
      } else {
        if (context.mounted) {
          Navigator.of(context).pop();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('检查更新'),
              content: const Text('检查更新失败，请稍后重试。'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('确定'))],
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('检查更新'),
            content: Text('检查更新失败: $e'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('确定'))],
          ),
        );
      }
    }
  }
}
