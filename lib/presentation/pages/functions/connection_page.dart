import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/core/utils/session_cleanup.dart';
import 'package:mi_music/data/providers/settings_provider.dart';
import 'package:mi_music/presentation/widgets/setting_host_port_check_listener.dart';

final _logger = Logger();

/// 账号设置 Section
class ConnectionPage extends ConsumerStatefulWidget {
  const ConnectionPage({super.key});

  @override
  ConsumerState<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends ConsumerState<ConnectionPage> {
  late TextEditingController _urlController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _urlController = TextEditingController(text: settings.serverUrl);
    _usernameController = TextEditingController(text: settings.username);
    _passwordController = TextEditingController(text: settings.password);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);

    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final oldServerUrl = ref.read(settingsProvider).serverUrl.trim();

    // 先写入配置，再测连，这样 getSetting 会用当前输入的地址
    await ref.read(settingsProvider.notifier).setApiConfig(url, username, password);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.getVersion();

      if (mounted) {
        // 仅当地址发生变化时清空缓存与状态，避免同一服务重复测连时误清
        if (url != oldServerUrl) {
          await clearServerData(ref);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(S.connected), backgroundColor: AppColors.success));
        // 连接成功后检查 getSetting 与当前连接 host/port 是否一致
        final mismatch = await checkSettingHostPortMatch(ref);
        if (mounted && mismatch != null) {
          await showHostPortMismatchDialog(context, ref, mismatch);
        }
      }
    } catch (e) {
      _logger.e("连接服务器失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${S.connectionFailed}: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(S.logout),
        content: const Text(S.logoutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(S.logout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await clearServerData(ref);
      await ref.read(settingsProvider.notifier).setServerUrl('');
      await ref.read(settingsProvider.notifier).setCredentials('', '');
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.connectionConfig)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: S.serverUrl,
                hintText: S.serverUrlHint,
                prefixIcon: const Icon(Icons.dns_rounded),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: S.usernameOptional,
                prefixIcon: const Icon(Icons.person_rounded),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: S.passwordOptional,
                prefixIcon: const Icon(Icons.lock_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              obscureText: _obscurePassword,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testConnection,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_find_rounded),
              label: Text(_isLoading ? S.connecting : S.testConnection),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text(S.logout),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
