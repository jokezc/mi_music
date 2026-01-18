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

/// 对话提示音配置 Section
class DialogTtsSection extends ConsumerStatefulWidget {
  const DialogTtsSection({super.key});

  @override
  ConsumerState<DialogTtsSection> createState() => _DialogTtsSectionState();
}

class _DialogTtsSectionState extends ConsumerState<DialogTtsSection> {
  late TextEditingController _pullAskSecController;
  late TextEditingController _stopTtsMsgController;
  late TextEditingController _playTypeOneTtsMsgController;
  late TextEditingController _playTypeAllTtsMsgController;
  late TextEditingController _playTypeRndTtsMsgController;
  late TextEditingController _playTypeSinTtsMsgController;
  late TextEditingController _playTypeSeqTtsMsgController;
  bool _isLoading = false;
  bool _enablePullAsk = false;
  bool _getAskByMina = false;
  SystemSetting? _currentSetting;

  @override
  void initState() {
    super.initState();
    _pullAskSecController = TextEditingController();
    _stopTtsMsgController = TextEditingController();
    _playTypeOneTtsMsgController = TextEditingController();
    _playTypeAllTtsMsgController = TextEditingController();
    _playTypeRndTtsMsgController = TextEditingController();
    _playTypeSinTtsMsgController = TextEditingController();
    _playTypeSeqTtsMsgController = TextEditingController();
  }

  @override
  void dispose() {
    _pullAskSecController.dispose();
    _stopTtsMsgController.dispose();
    _playTypeOneTtsMsgController.dispose();
    _playTypeAllTtsMsgController.dispose();
    _playTypeRndTtsMsgController.dispose();
    _playTypeSinTtsMsgController.dispose();
    _playTypeSeqTtsMsgController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final setting = await apiClient.getSetting(true);
      setState(() {
        _currentSetting = setting;
        _enablePullAsk = setting.enablePullAsk ?? false;
        _pullAskSecController.text =
            setting.pullAskSec?.toString() ?? '1';
        _getAskByMina = setting.getAskByMina ?? false;
        _stopTtsMsgController.text = setting.stopTtsMsg ?? '';
        _playTypeOneTtsMsgController.text =
            setting.playTypeOneTtsMsg ?? '';
        _playTypeAllTtsMsgController.text =
            setting.playTypeAllTtsMsg ?? '';
        _playTypeRndTtsMsgController.text =
            setting.playTypeRndTtsMsg ?? '';
        _playTypeSinTtsMsgController.text =
            setting.playTypeSinTtsMsg ?? '';
        _playTypeSeqTtsMsgController.text =
            setting.playTypeSeqTtsMsg ?? '';
      });
    } catch (e) {
      _logger.e("加载设置失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${S.errorLoading}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_currentSetting == null) return;

    setState(() => _isLoading = true);

    try {
      final pullAskSec = int.tryParse(_pullAskSecController.text.trim());

      final updatedSetting = _currentSetting!.copyWith(
        enablePullAsk: _enablePullAsk,
        pullAskSec: pullAskSec,
        getAskByMina: _getAskByMina,
        stopTtsMsg: _stopTtsMsgController.text.trim().isEmpty
            ? null
            : _stopTtsMsgController.text.trim(),
        playTypeOneTtsMsg: _playTypeOneTtsMsgController.text.trim().isEmpty
            ? null
            : _playTypeOneTtsMsgController.text.trim(),
        playTypeAllTtsMsg: _playTypeAllTtsMsgController.text.trim().isEmpty
            ? null
            : _playTypeAllTtsMsgController.text.trim(),
        playTypeRndTtsMsg: _playTypeRndTtsMsgController.text.trim().isEmpty
            ? null
            : _playTypeRndTtsMsgController.text.trim(),
        playTypeSinTtsMsg: _playTypeSinTtsMsgController.text.trim().isEmpty
            ? null
            : _playTypeSinTtsMsgController.text.trim(),
        playTypeSeqTtsMsg: _playTypeSeqTtsMsgController.text.trim().isEmpty
            ? null
            : _playTypeSeqTtsMsgController.text.trim(),
      );

      final apiClient = ref.read(apiClientProvider);
      await apiClient.saveSetting(updatedSetting);

      // 刷新设置
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(S.saveSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      _logger.e("保存设置失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${S.saveFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
                    S.dialogSettings,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text(S.getDialogueRecords),
                value: _enablePullAsk,
                onChanged: (value) {
                  setState(() => _enablePullAsk = value);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pullAskSecController,
                decoration: InputDecoration(
                  labelText: S.getDialogueInterval,
                  prefixIcon: const Icon(Icons.timer),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text(S.specialModelGetDialogueRecords),
                value: _getAskByMina,
                onChanged: (value) {
                  setState(() => _getAskByMina = value);
                },
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _stopTtsMsgController,
                decoration: InputDecoration(
                  labelText: S.stopPromptTone,
                  prefixIcon: const Icon(Icons.stop),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _playTypeOneTtsMsgController,
                decoration: InputDecoration(
                  labelText: S.singleSongLoopPromptTone,
                  prefixIcon: const Icon(Icons.repeat_one),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _playTypeAllTtsMsgController,
                decoration: InputDecoration(
                  labelText: S.allLoopPromptTone,
                  prefixIcon: const Icon(Icons.repeat),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _playTypeRndTtsMsgController,
                decoration: InputDecoration(
                  labelText: S.randomPlayPromptTone,
                  prefixIcon: const Icon(Icons.shuffle),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _playTypeSinTtsMsgController,
                decoration: InputDecoration(
                  labelText: S.singleSongPlayPromptTone,
                  prefixIcon: const Icon(Icons.music_note),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _playTypeSeqTtsMsgController,
                decoration: InputDecoration(
                  labelText: S.sequentialPlayPromptTone,
                  prefixIcon: const Icon(Icons.queue_music),
                  border: const OutlineInputBorder(),
                ),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(S.saveChanges),
              ),
            ],
          ),
        );
  }
}
