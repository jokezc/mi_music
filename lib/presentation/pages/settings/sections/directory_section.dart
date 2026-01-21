import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/core/theme/app_colors.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';

final _logger = Logger();

/// 目录配置 Section
class DirectorySection extends ConsumerStatefulWidget {
  const DirectorySection({super.key});

  @override
  ConsumerState<DirectorySection> createState() => _DirectorySectionState();
}

class _DirectorySectionState extends ConsumerState<DirectorySection> {
  late TextEditingController _musicPathController;
  late TextEditingController _downloadPathController;
  late TextEditingController _tempPathController;
  late TextEditingController _confPathController;
  late TextEditingController _cacheDirController;
  late TextEditingController _logFileController;
  late TextEditingController _ffmpegLocationController;
  late TextEditingController _excludeDirsController;
  late TextEditingController _ignoreTagDirsController;
  late TextEditingController _musicPathDepthController;
  bool _isLoading = false;
  SystemSetting? _currentSetting;

  @override
  void initState() {
    super.initState();
    _musicPathController = TextEditingController();
    _downloadPathController = TextEditingController();
    _tempPathController = TextEditingController();
    _confPathController = TextEditingController();
    _cacheDirController = TextEditingController();
    _logFileController = TextEditingController();
    _ffmpegLocationController = TextEditingController();
    _excludeDirsController = TextEditingController();
    _ignoreTagDirsController = TextEditingController();
    _musicPathDepthController = TextEditingController();
  }

  @override
  void dispose() {
    _musicPathController.dispose();
    _downloadPathController.dispose();
    _tempPathController.dispose();
    _confPathController.dispose();
    _cacheDirController.dispose();
    _logFileController.dispose();
    _ffmpegLocationController.dispose();
    _excludeDirsController.dispose();
    _ignoreTagDirsController.dispose();
    _musicPathDepthController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final setting = await apiClient.getSetting(false);
      setState(() {
        _currentSetting = setting;
        _musicPathController.text = setting.musicPath ?? '';
        _downloadPathController.text = setting.downloadPath ?? '';
        _tempPathController.text = setting.tempPath ?? '';
        _confPathController.text = setting.confPath ?? '';
        _cacheDirController.text = setting.cacheDir ?? '';
        _logFileController.text = setting.logFile ?? '';
        _ffmpegLocationController.text = setting.ffmpegLocation ?? '';
        _excludeDirsController.text = setting.excludeDirs ?? '';
        _ignoreTagDirsController.text = setting.ignoreTagDirs ?? '';
        _musicPathDepthController.text = setting.musicPathDepth?.toString() ?? '';
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
      final musicPathDepth = int.tryParse(_musicPathDepthController.text.trim());

      final updatedSetting = _currentSetting!.copyWith(
        musicPath: _musicPathController.text.trim().isEmpty ? null : _musicPathController.text.trim(),
        downloadPath: _downloadPathController.text.trim().isEmpty ? null : _downloadPathController.text.trim(),
        tempPath: _tempPathController.text.trim().isEmpty ? null : _tempPathController.text.trim(),
        confPath: _confPathController.text.trim().isEmpty ? null : _confPathController.text.trim(),
        cacheDir: _cacheDirController.text.trim().isEmpty ? null : _cacheDirController.text.trim(),
        logFile: _logFileController.text.trim().isEmpty ? null : _logFileController.text.trim(),
        ffmpegLocation: _ffmpegLocationController.text.trim().isEmpty ? null : _ffmpegLocationController.text.trim(),
        excludeDirs: _excludeDirsController.text.trim().isEmpty ? null : _excludeDirsController.text.trim(),
        ignoreTagDirs: _ignoreTagDirsController.text.trim().isEmpty ? null : _ignoreTagDirsController.text.trim(),
        musicPathDepth: musicPathDepth,
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
                S.directorySettings,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _musicPathController,
            decoration: InputDecoration(
              labelText: S.musicDirectory,
              prefixIcon: const Icon(Icons.folder_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _downloadPathController,
            decoration: InputDecoration(
              labelText: S.musicDownloadDirectory,
              prefixIcon: const Icon(Icons.download_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tempPathController,
            decoration: InputDecoration(
              labelText: S.tempFileDirectory,
              prefixIcon: const Icon(Icons.folder_special_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confPathController,
            decoration: InputDecoration(
              labelText: S.configFileDirectory,
              prefixIcon: const Icon(Icons.settings_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cacheDirController,
            decoration: InputDecoration(
              labelText: S.cacheFileDirectory,
              prefixIcon: const Icon(Icons.cached_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _logFileController,
            decoration: InputDecoration(
              labelText: S.logFile,
              prefixIcon: const Icon(Icons.description_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ffmpegLocationController,
            decoration: InputDecoration(
              labelText: S.ffmpegPath,
              prefixIcon: const Icon(Icons.video_library_rounded),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _excludeDirsController,
            decoration: InputDecoration(
              labelText: S.excludeDirs,
              prefixIcon: const Icon(Icons.block_rounded),
              border: const OutlineInputBorder(),
              helperText: '多个目录用逗号分隔',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ignoreTagDirsController,
            decoration: InputDecoration(
              labelText: S.ignoreTagDirs,
              prefixIcon: const Icon(Icons.label_off_rounded),
              border: const OutlineInputBorder(),
              helperText: '多个目录用逗号分隔',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _musicPathDepthController,
            decoration: InputDecoration(
              labelText: S.musicPathDepth,
              prefixIcon: const Icon(Icons.layers_rounded),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

extension SystemSettingCopyWith on SystemSetting {
  SystemSetting copyWith({
    String? account,
    String? password,
    String? miDid,
    String? cookie,
    bool? verbose,
    String? musicPath,
    String? tempPath,
    String? downloadPath,
    String? confPath,
    String? cacheDir,
    String? hostname,
    int? port,
    int? publicPort,
    String? proxy,
    String? loudnorm,
    String? searchPrefix,
    String? ffmpegLocation,
    String? getDurationType,
    String? activeCmd,
    String? excludeDirs,
    String? ignoreTagDirs,
    int? musicPathDepth,
    bool? disableHttpAuth,
    String? httpAuthUsername,
    String? httpAuthPassword,
    String? musicListUrl,
    String? musicListJson,
    String? customPlayListJson,
    bool? disableDownload,
    Map<String, String>? keyWordDict,
    List<String>? keyMatchOrder,
    String? useMusicApi,
    String? useMusicAudioId,
    String? useMusicId,
    String? logFile,
    double? fuzzyMatchCutoff,
    bool? enableFuzzyMatch,
    String? stopTtsMsg,
    bool? enableConfigExample,
    String? keywordsPlayLocal,
    String? keywordsSearchPlayLocal,
    String? keywordsPlay,
    String? keywordsSearchPlay,
    String? keywordsStop,
    String? keywordsPlaylist,
    Map<String, String>? userKeyWordDict,
    bool? enableForceStop,
    Map<String, Device>? devices,
    String? groupList,
    bool? removeId3Tag,
    bool? convertToMp3,
    String? delaySec,
    String? continuePlay,
    bool? enableFileWatch,
    int? fileWatchDebounce,
    int? pullAskSec,
    bool? enablePullAsk,
    String? crontabJson,
    bool? enableYtDlpCookies,
    bool? enableSaveTag,
    bool? enableAnalytics,
    bool? getAskByMina,
    String? playTypeOneTtsMsg,
    String? playTypeAllTtsMsg,
    String? playTypeRndTtsMsg,
    String? playTypeSinTtsMsg,
    String? playTypeSeqTtsMsg,
    int? recentlyAddedPlaylistLen,
    bool? enableCmdDelMusic,
    int? searchMusicCount,
    bool? webMusicProxy,
    List<DeviceListItem>? deviceList,
  }) {
    return SystemSetting(
      account: account ?? this.account,
      password: password ?? this.password,
      miDid: miDid ?? this.miDid,
      cookie: cookie ?? this.cookie,
      verbose: verbose ?? this.verbose,
      musicPath: musicPath ?? this.musicPath,
      tempPath: tempPath ?? this.tempPath,
      downloadPath: downloadPath ?? this.downloadPath,
      confPath: confPath ?? this.confPath,
      cacheDir: cacheDir ?? this.cacheDir,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      publicPort: publicPort ?? this.publicPort,
      proxy: proxy ?? this.proxy,
      loudnorm: loudnorm ?? this.loudnorm,
      searchPrefix: searchPrefix ?? this.searchPrefix,
      ffmpegLocation: ffmpegLocation ?? this.ffmpegLocation,
      getDurationType: getDurationType ?? this.getDurationType,
      activeCmd: activeCmd ?? this.activeCmd,
      excludeDirs: excludeDirs ?? this.excludeDirs,
      ignoreTagDirs: ignoreTagDirs ?? this.ignoreTagDirs,
      musicPathDepth: musicPathDepth ?? this.musicPathDepth,
      disableHttpAuth: disableHttpAuth ?? this.disableHttpAuth,
      httpAuthUsername: httpAuthUsername ?? this.httpAuthUsername,
      httpAuthPassword: httpAuthPassword ?? this.httpAuthPassword,
      musicListUrl: musicListUrl ?? this.musicListUrl,
      musicListJson: musicListJson ?? this.musicListJson,
      customPlayListJson: customPlayListJson ?? this.customPlayListJson,
      disableDownload: disableDownload ?? this.disableDownload,
      keyWordDict: keyWordDict ?? this.keyWordDict,
      keyMatchOrder: keyMatchOrder ?? this.keyMatchOrder,
      useMusicApi: useMusicApi ?? this.useMusicApi,
      useMusicAudioId: useMusicAudioId ?? this.useMusicAudioId,
      useMusicId: useMusicId ?? this.useMusicId,
      logFile: logFile ?? this.logFile,
      fuzzyMatchCutoff: fuzzyMatchCutoff ?? this.fuzzyMatchCutoff,
      enableFuzzyMatch: enableFuzzyMatch ?? this.enableFuzzyMatch,
      stopTtsMsg: stopTtsMsg ?? this.stopTtsMsg,
      enableConfigExample: enableConfigExample ?? this.enableConfigExample,
      keywordsPlayLocal: keywordsPlayLocal ?? this.keywordsPlayLocal,
      keywordsSearchPlayLocal: keywordsSearchPlayLocal ?? this.keywordsSearchPlayLocal,
      keywordsPlay: keywordsPlay ?? this.keywordsPlay,
      keywordsSearchPlay: keywordsSearchPlay ?? this.keywordsSearchPlay,
      keywordsStop: keywordsStop ?? this.keywordsStop,
      keywordsPlaylist: keywordsPlaylist ?? this.keywordsPlaylist,
      userKeyWordDict: userKeyWordDict ?? this.userKeyWordDict,
      enableForceStop: enableForceStop ?? this.enableForceStop,
      devices: devices ?? this.devices,
      groupList: groupList ?? this.groupList,
      removeId3Tag: removeId3Tag ?? this.removeId3Tag,
      convertToMp3: convertToMp3 ?? this.convertToMp3,
      delaySec: delaySec ?? this.delaySec,
      continuePlay: continuePlay ?? this.continuePlay,
      enableFileWatch: enableFileWatch ?? this.enableFileWatch,
      fileWatchDebounce: fileWatchDebounce ?? this.fileWatchDebounce,
      pullAskSec: pullAskSec ?? this.pullAskSec,
      enablePullAsk: enablePullAsk ?? this.enablePullAsk,
      crontabJson: crontabJson ?? this.crontabJson,
      enableYtDlpCookies: enableYtDlpCookies ?? this.enableYtDlpCookies,
      enableSaveTag: enableSaveTag ?? this.enableSaveTag,
      enableAnalytics: enableAnalytics ?? this.enableAnalytics,
      getAskByMina: getAskByMina ?? this.getAskByMina,
      playTypeOneTtsMsg: playTypeOneTtsMsg ?? this.playTypeOneTtsMsg,
      playTypeAllTtsMsg: playTypeAllTtsMsg ?? this.playTypeAllTtsMsg,
      playTypeRndTtsMsg: playTypeRndTtsMsg ?? this.playTypeRndTtsMsg,
      playTypeSinTtsMsg: playTypeSinTtsMsg ?? this.playTypeSinTtsMsg,
      playTypeSeqTtsMsg: playTypeSeqTtsMsg ?? this.playTypeSeqTtsMsg,
      recentlyAddedPlaylistLen: recentlyAddedPlaylistLen ?? this.recentlyAddedPlaylistLen,
      enableCmdDelMusic: enableCmdDelMusic ?? this.enableCmdDelMusic,
      searchMusicCount: searchMusicCount ?? this.searchMusicCount,
      webMusicProxy: webMusicProxy ?? this.webMusicProxy,
      deviceList: deviceList ?? this.deviceList,
    );
  }
}
