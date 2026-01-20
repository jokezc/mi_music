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

/// 播放配置 Section
class PlaySection extends ConsumerStatefulWidget {
  const PlaySection({super.key});

  @override
  ConsumerState<PlaySection> createState() => _PlaySectionState();
}

class _PlaySectionState extends ConsumerState<PlaySection> {
  late TextEditingController _loudnormController;
  late TextEditingController _delaySecController;
  late TextEditingController _fuzzyMatchCutoffController;
  String? _searchPrefix;
  String? _getDurationType;
  bool _isLoading = false;
  bool _removeId3Tag = false;
  bool _convertToMp3 = false;
  bool _enableFuzzyMatch = false;
  bool _disableDownload = false;
  SystemSetting? _currentSetting;

  @override
  void initState() {
    super.initState();
    _loudnormController = TextEditingController();
    _delaySecController = TextEditingController();
    _fuzzyMatchCutoffController = TextEditingController();
  }

  @override
  void dispose() {
    _loudnormController.dispose();
    _delaySecController.dispose();
    _fuzzyMatchCutoffController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final setting = await apiClient.getSetting(false);
      setState(() {
        _currentSetting = setting;
        _searchPrefix = setting.searchPrefix;
        _getDurationType = setting.getDurationType;
        _loudnormController.text = setting.loudnorm ?? '';
        _removeId3Tag = setting.removeId3Tag ?? false;
        _convertToMp3 = setting.convertToMp3 ?? false;
        _delaySecController.text = setting.delaySec ?? '';
        _enableFuzzyMatch = setting.enableFuzzyMatch ?? false;
        _fuzzyMatchCutoffController.text = setting.fuzzyMatchCutoff?.toString() ?? '0.6';
        _disableDownload = setting.disableDownload ?? false;
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
      final delaySec = _delaySecController.text.trim();
      final fuzzyMatchCutoff = double.tryParse(_fuzzyMatchCutoffController.text.trim());

      final updatedSetting = _currentSetting!.copyWith(
        searchPrefix: _searchPrefix,
        getDurationType: _getDurationType,
        loudnorm: _loudnormController.text.trim().isEmpty ? null : _loudnormController.text.trim(),
        removeId3Tag: _removeId3Tag,
        convertToMp3: _convertToMp3,
        delaySec: delaySec.isEmpty ? null : delaySec,
        enableFuzzyMatch: _enableFuzzyMatch,
        fuzzyMatchCutoff: fuzzyMatchCutoff,
        disableDownload: _disableDownload,
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
                S.playSettings,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _searchPrefix,
            decoration: InputDecoration(
              labelText: S.searchPrefix,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'bilisearch:', child: Text('bilisearch:')),
              DropdownMenuItem(value: 'ytsearch:', child: Text('ytsearch:')),
            ],
            onChanged: (value) {
              setState(() => _searchPrefix = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _getDurationType,
            decoration: InputDecoration(
              labelText: S.getDurationType,
              prefixIcon: const Icon(Icons.timer),
              border: const OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'ffprobe', child: Text('ffprobe')),
              DropdownMenuItem(value: 'mutagen', child: Text('mutagen')),
            ],
            onChanged: (value) {
              setState(() => _getDurationType = value);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _loudnormController,
            decoration: InputDecoration(
              labelText: S.loudnorm,
              prefixIcon: const Icon(Icons.volume_up),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(S.removeId3tag),
            value: _removeId3Tag,
            onChanged: (value) {
              setState(() => _removeId3Tag = value);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text(S.convertToMp3),
            value: _convertToMp3,
            onChanged: (value) {
              setState(() => _convertToMp3 = value);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _delaySecController,
            decoration: InputDecoration(
              labelText: S.delaySec,
              prefixIcon: const Icon(Icons.schedule),
              border: const OutlineInputBorder(),
              helperText: '支持负数',
            ),
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*\.?\d*'))],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(S.enableFuzzyMatch),
            value: _enableFuzzyMatch,
            onChanged: (value) {
              setState(() => _enableFuzzyMatch = value);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _fuzzyMatchCutoffController,
            decoration: InputDecoration(
              labelText: S.fuzzyMatchCutoff,
              prefixIcon: const Icon(Icons.tune),
              border: const OutlineInputBorder(),
              helperText: '范围: 0.1 ~ 0.9',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^0\.[1-9]\d*$|^0\.9$|^0\.\d*$'))],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(S.disableDownload),
            value: _disableDownload,
            onChanged: (value) {
              setState(() => _disableDownload = value);
            },
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
