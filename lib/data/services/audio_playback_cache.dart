import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class AudioPlaybackCache {
  AudioPlaybackCache._();

  static final AudioPlaybackCache instance = AudioPlaybackCache._();

  final CacheManager _cacheManager = CacheManager(
    Config(
      'mi_music_audio_cache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 200,
    ),
  );

  final Map<String, Future<void>> _warmingTasks = {};

  Future<File?> getCachedFile(String url) async {
    try {
      final cached = await _cacheManager.getFileFromCache(url);
      final file = cached?.file;
      if (file == null || !await file.exists()) {
        return null;
      }
      return file;
    } catch (e) {
      _logger.w('读取音频缓存失败: $e');
      return null;
    }
  }

  Future<void> warm(String url) {
    final existing = _warmingTasks[url];
    if (existing != null) {
      return existing;
    }

    final task = _cacheManager.downloadFile(url).then((_) {}).catchError((Object e, StackTrace st) {
      _logger.w('预热音频缓存失败: $url, error: $e');
    }).whenComplete(() {
      _warmingTasks.remove(url);
    });

    _warmingTasks[url] = task;
    return task;
  }

  Future<void> remove(String url) async {
    try {
      await _cacheManager.removeFile(url);
    } catch (e) {
      _logger.w('移除音频缓存失败: $url, error: $e');
    }
  }
}
