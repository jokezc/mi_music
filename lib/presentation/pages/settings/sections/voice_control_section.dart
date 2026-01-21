import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/presentation/pages/settings/sections/directory_section.dart';

final _logger = Logger();

/// 语音控制配置 Section
class VoiceControlSection extends ConsumerStatefulWidget {
  const VoiceControlSection({super.key});

  @override
  ConsumerState<VoiceControlSection> createState() => _VoiceControlSectionState();
}

class _VoiceControlSectionState extends ConsumerState<VoiceControlSection> {
  late TextEditingController _activeCmdController;
  late TextEditingController _keywordsPlayLocalController;
  late TextEditingController _keywordsSearchPlayLocalController;
  late TextEditingController _keywordsPlayController;
  late TextEditingController _keywordsSearchPlayController;
  late TextEditingController _keywordsStopController;
  late TextEditingController _keywordsPlaylistController;
  bool _isLoading = false;
  SystemSetting? _currentSetting;

  @override
  void initState() {
    super.initState();
    _activeCmdController = TextEditingController();
    _keywordsPlayLocalController = TextEditingController();
    _keywordsSearchPlayLocalController = TextEditingController();
    _keywordsPlayController = TextEditingController();
    _keywordsSearchPlayController = TextEditingController();
    _keywordsStopController = TextEditingController();
    _keywordsPlaylistController = TextEditingController();
  }

  @override
  void dispose() {
    _activeCmdController.dispose();
    _keywordsPlayLocalController.dispose();
    _keywordsSearchPlayLocalController.dispose();
    _keywordsPlayController.dispose();
    _keywordsSearchPlayController.dispose();
    _keywordsStopController.dispose();
    _keywordsPlaylistController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final setting = await apiClient.getSetting(false);
      setState(() {
        _currentSetting = setting;
        _activeCmdController.text = setting.activeCmd ?? '';
        _keywordsPlayLocalController.text = setting.keywordsPlayLocal ?? '';
        _keywordsSearchPlayLocalController.text = setting.keywordsSearchPlayLocal ?? '';
        _keywordsPlayController.text = setting.keywordsPlay ?? '';
        _keywordsSearchPlayController.text = setting.keywordsSearchPlay ?? '';
        _keywordsStopController.text = setting.keywordsStop ?? '';
        _keywordsPlaylistController.text = setting.keywordsPlaylist ?? '';
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
      final updatedSetting = _currentSetting!.copyWith(
        activeCmd: _activeCmdController.text.trim().isEmpty ? null : _activeCmdController.text.trim(),
        keywordsPlayLocal: _keywordsPlayLocalController.text.trim().isEmpty
            ? null
            : _keywordsPlayLocalController.text.trim(),
        keywordsSearchPlayLocal: _keywordsSearchPlayLocalController.text.trim().isEmpty
            ? null
            : _keywordsSearchPlayLocalController.text.trim(),
        keywordsPlay: _keywordsPlayController.text.trim().isEmpty ? null : _keywordsPlayController.text.trim(),
        keywordsSearchPlay: _keywordsSearchPlayController.text.trim().isEmpty
            ? null
            : _keywordsSearchPlayController.text.trim(),
        keywordsStop: _keywordsStopController.text.trim().isEmpty ? null : _keywordsStopController.text.trim(),
        keywordsPlaylist: _keywordsPlaylistController.text.trim().isEmpty
            ? null
            : _keywordsPlaylistController.text.trim(),
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
              const Icon(Icons.settings_rounded, size: 24),
              const SizedBox(width: 8),
              Text(
                S.voiceSettings,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _activeCmdController,
            decoration: InputDecoration(
              labelText: S.allowedWakeupCommands,
              prefixIcon: const Icon(Icons.mic_rounded),
              border: const OutlineInputBorder(),
              helperText: '多个命令用逗号分隔',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywordsPlayLocalController,
            decoration: InputDecoration(
              labelText: S.playLocalSongCommand,
              prefixIcon: const Icon(Icons.music_note_rounded),
              border: const OutlineInputBorder(),
              helperText: '多个口令用逗号分隔',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywordsPlayController,
            decoration: InputDecoration(
              labelText: S.playSongCommand,
              prefixIcon: const Icon(Icons.play_arrow_rounded),
              border: const OutlineInputBorder(),
              helperText: '多个口令用逗号分隔',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywordsPlaylistController,
            decoration: InputDecoration(
              labelText: S.playListCommand,
              prefixIcon: const Icon(Icons.queue_music_rounded),
              border: const OutlineInputBorder(),
              helperText: '多个口令用逗号分隔',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywordsStopController,
            decoration: InputDecoration(
              labelText: S.stopCommand,
              prefixIcon: const Icon(Icons.stop_rounded),
              border: const OutlineInputBorder(),
              helperText: '多个口令用逗号分隔',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywordsSearchPlayLocalController,
            decoration: InputDecoration(
              labelText: S.localSearchPlayCommand,
              prefixIcon: const Icon(Icons.search_rounded),
              border: const OutlineInputBorder(),
              helperText: '多个口令用逗号分隔',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keywordsSearchPlayController,
            decoration: InputDecoration(
              labelText: S.searchPlayCommand,
              prefixIcon: const Icon(Icons.search_rounded),
              border: const OutlineInputBorder(),
              helperText: '多个口令用逗号分隔',
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
