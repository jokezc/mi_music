import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/presentation/pages/settings/sections/directory_section.dart';

final _logger = Logger();

/// 服务配置 Section
class ServiceSection extends ConsumerStatefulWidget {
  const ServiceSection({super.key});

  @override
  ConsumerState<ServiceSection> createState() => _ServiceSectionState();
}

class _ServiceSectionState extends ConsumerState<ServiceSection> {
  late TextEditingController _hostnameController;
  late TextEditingController _portController;
  late TextEditingController _publicPortController;
  late TextEditingController _proxyController;
  late TextEditingController _httpAuthUsernameController;
  late TextEditingController _httpAuthPasswordController;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _disableHttpAuth = false;
  SystemSetting? _currentSetting;

  @override
  void initState() {
    super.initState();
    _hostnameController = TextEditingController();
    _portController = TextEditingController();
    _publicPortController = TextEditingController();
    _proxyController = TextEditingController();
    _httpAuthUsernameController = TextEditingController();
    _httpAuthPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _hostnameController.dispose();
    _portController.dispose();
    _publicPortController.dispose();
    _proxyController.dispose();
    _httpAuthUsernameController.dispose();
    _httpAuthPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final setting = await apiClient.getSetting(false);
      setState(() {
        _currentSetting = setting;
        _hostnameController.text = setting.hostname ?? '';
        _portController.text = setting.port?.toString() ?? '';
        _publicPortController.text = setting.publicPort?.toString() ?? '';
        _proxyController.text = setting.proxy ?? '';
        _disableHttpAuth = setting.disableHttpAuth ?? false;
        _httpAuthUsernameController.text = setting.httpAuthUsername ?? '';
        _httpAuthPasswordController.text = setting.httpAuthPassword == '******' ? '' : (setting.httpAuthPassword ?? '');
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
      final port = int.tryParse(_portController.text.trim());
      final publicPort = int.tryParse(_publicPortController.text.trim());

      final updatedSetting = _currentSetting!.copyWith(
        hostname: _hostnameController.text.trim().isEmpty ? null : _hostnameController.text.trim(),
        port: port,
        publicPort: publicPort,
        proxy: _proxyController.text.trim().isEmpty ? null : _proxyController.text.trim(),
        disableHttpAuth: _disableHttpAuth,
        httpAuthUsername: _httpAuthUsernameController.text.trim().isEmpty
            ? null
            : _httpAuthUsernameController.text.trim(),
        httpAuthPassword: _httpAuthPasswordController.text.trim().isEmpty
            ? '******'
            : _httpAuthPasswordController.text.trim(),
      );

      final apiClient = ref.read(apiClientProvider);
      await apiClient.saveSetting(updatedSetting);

      // 刷新设置
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(S.saveSuccess), backgroundColor: AppColors.success));
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
                S.serviceSettings,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _hostnameController,
            decoration: InputDecoration(
              labelText: S.hostnameIp,
              prefixIcon: const Icon(Icons.dns),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _portController,
            decoration: InputDecoration(
              labelText: S.localPort,
              prefixIcon: const Icon(Icons.numbers),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _publicPortController,
            decoration: InputDecoration(
              labelText: S.publicPort,
              prefixIcon: const Icon(Icons.numbers),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _proxyController,
            decoration: InputDecoration(
              labelText: S.proxyAddress,
              hintText: S.proxyAddressHint,
              prefixIcon: const Icon(Icons.vpn_key),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(S.disableHttpAuth),
            value: _disableHttpAuth,
            onChanged: (value) {
              setState(() => _disableHttpAuth = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _httpAuthUsernameController,
            decoration: InputDecoration(
              labelText: S.httpAuthUsername,
              prefixIcon: const Icon(Icons.person),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _httpAuthPasswordController,
            decoration: InputDecoration(
              labelText: S.httpAuthPassword,
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
