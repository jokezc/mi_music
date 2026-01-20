import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/presentation/pages/settings/sections/directory_section.dart';

final _logger = Logger();

/// 账号设置 Section
class AccountSection extends ConsumerStatefulWidget {
  const AccountSection({super.key});

  @override
  ConsumerState<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<AccountSection> {
  late TextEditingController _accountController;
  late TextEditingController _passwordController;
  bool _isLoading = false;
  bool _obscurePassword = true;
  SystemSetting? _currentSetting;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final setting = await apiClient.getSetting(false);
      setState(() {
        _currentSetting = setting;
        _accountController.text = setting.account;
        _passwordController.text = setting.password == '******' ? '' : setting.password;
      });
    } catch (e) {
      _logger.e("加载设置失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${S.errorLoading}: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_currentSetting == null) return;

    setState(() => _isLoading = true);

    try {
      final account = _accountController.text.trim();
      final password = _passwordController.text.trim();

      // 如果密码为空或为******，保持原值
      final passwordToSave = password.isEmpty ? '******' : password;

      final updatedSetting = _currentSetting!.copyWith(account: account, password: passwordToSave);

      final apiClient = ref.read(apiClientProvider);
      await apiClient.saveSetting(updatedSetting);

      // 刷新设置
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(S.saveSuccess), backgroundColor: AppColors.success));
        await _loadSettings();
      }
    } catch (e) {
      _logger.e("保存设置失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${S.saveFailed}: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 首次加载时获取设置
    if (_currentSetting == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSettings();
      });
    }

    if (_currentSetting == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, size: 24),
              const SizedBox(width: 8),
              Text(
                S.accountSettings,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _accountController,
            decoration: InputDecoration(
              labelText: S.xiaomiAccount,
              prefixIcon: const Icon(Icons.account_circle),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: S.password,
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            obscureText: _obscurePassword,
          ),
          const SizedBox(height: 16),
          TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: S.xiaomiAccountDid,
              prefixIcon: const Icon(Icons.device_hub),
              border: const OutlineInputBorder(),
              helperText: '只读',
            ),
            controller: TextEditingController(text: _currentSetting!.miDid.isEmpty ? '未设置' : _currentSetting!.miDid),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(S.saveChanges),
          ),
        ],
      ),
    );
  }
}
