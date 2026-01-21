import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';

final _logger = Logger();

/// 下载页面
class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key});

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.download)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 下载单曲卡片
            Card(
              child: Padding(padding: const EdgeInsets.all(16), child: _DownloadMusicForm()),
            ),
            const SizedBox(height: 16),
            // 下载歌单卡片
            Card(
              child: Padding(padding: const EdgeInsets.all(16), child: _DownloadPlaylistForm()),
            ),
          ],
        ),
      ),
    );
  }
}

/// 下载单曲表单
class _DownloadMusicForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DownloadMusicForm> createState() => _DownloadMusicFormState();
}

class _DownloadMusicFormState extends ConsumerState<_DownloadMusicForm> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_urlController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(apiClientProvider)
          .downloadOneMusic(DownloadOneMusic(url: _urlController.text.trim(), name: _nameController.text.trim()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.downloadSuccess)));
        _urlController.clear();
        _nameController.clear();
      }
    } catch (e) {
      _logger.e("下载歌曲失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.downloadFailed}: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.downloadMusic, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: S.musicUrl,
            hintText: S.musicUrlHint,
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '歌曲名称（可选）',
            hintText: '自定义歌曲名称',
            prefixIcon: Icon(Icons.music_note_rounded),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _download,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded),
            label: Text(_isLoading ? S.downloading : S.download),
          ),
        ),
      ],
    );
  }
}

/// 下载歌单表单
class _DownloadPlaylistForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DownloadPlaylistForm> createState() => _DownloadPlaylistFormState();
}

class _DownloadPlaylistFormState extends ConsumerState<_DownloadPlaylistForm> {
  final _urlController = TextEditingController();
  final _dirnameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _dirnameController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    if (_urlController.text.trim().isEmpty || _dirnameController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref
          .read(apiClientProvider)
          .downloadPlaylist(DownloadPlayList(url: _urlController.text.trim(), dirname: _dirnameController.text.trim()));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.downloadSuccess)));
        _urlController.clear();
        _dirnameController.clear();
      }
    } catch (e) {
      _logger.e("下载歌曲失败: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${S.downloadFailed}: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.downloadPlaylist, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: S.playlistUrl,
            hintText: S.playlistUrlHint,
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dirnameController,
          decoration: const InputDecoration(
            labelText: S.folderName,
            hintText: S.folderNameHint,
            prefixIcon: Icon(Icons.folder_rounded),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _download,
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded),
            label: Text(_isLoading ? S.downloading : S.download),
          ),
        ),
      ],
    );
  }
}
