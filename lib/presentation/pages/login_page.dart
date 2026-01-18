import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/settings_provider.dart';

final _logger = Logger();

/// 登录/服务器连接页面
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    // Save temporarily to test connection
    // 使用批量设置方法，避免重复 invalidate apiConfigProvider
    await ref.read(settingsProvider.notifier).setApiConfig(url, username, password);

    try {
      // 使用认证验证来校验账号密码
      // skipStateUpdate: true 表示在登录页，不需要更新状态触发跳转，只返回错误信息
      final authResult = await verifyAuth(ref, skipStateUpdate: true);

      if (authResult.isAuthenticated) {
        // 认证成功，更新认证状态并显示版本信息
        ref.read(authStateProvider.notifier).setAuthorized();
        // 显示版本信息并跳转
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${S.connected} (版本: ${authResult.version ?? "未知"})'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/');
        }
      } else {
        // 认证失败或其他错误，显示错误信息（不跳转，因为已经在登录页）
        if (mounted) {
          final errorMessage =
              authResult.errorMessage ??
              (authResult.isAuthenticated == false
                  ? '认证失败：账号或密码错误'
                  : '${S.connectionFailed}: ${authResult.errorMessage ?? "未知错误"}');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      _logger.e("登录/连接服务器失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${S.connectionFailed}: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                // Logo/Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.music_note, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  S.appName,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '连接到 XiaoMusic 服务器',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                // Server URL
                TextFormField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: S.serverUrl,
                    hintText: S.serverUrlHint,
                    prefixIcon: const Icon(Icons.dns),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return S.pleaseEnterUrl;
                    }
                    if (!value.startsWith('http')) {
                      return S.urlMustStartWithHttp;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Username
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: S.usernameOptional, prefixIcon: const Icon(Icons.person)),
                ),
                const SizedBox(height: 16),
                // Password
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: S.passwordOptional,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 32),
                // Connect Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _connect,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(S.connect, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
