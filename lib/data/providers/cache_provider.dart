import 'package:logger/logger.dart';
import 'package:mi_music/core/constants/base_constants.dart';
import 'package:mi_music/core/constants/cmd_commands.dart';
import 'package:mi_music/data/cache/music_cache.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
// 注意：这里导入 player_provider 会造成循环依赖（cache -> player -> playlist -> cache）
// 但 Riverpod 的 provider 是运行时解析的，通过 ref.read 访问是运行时行为
// 只要不是直接的类型依赖（如函数参数类型），就不会有编译时问题
import 'package:mi_music/data/providers/player/player_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cache_provider.g.dart';

final _logger = Logger();

/// 缓存管理器 Provider
@riverpod
MusicCacheManager cacheManager(Ref ref) {
  final manager = MusicCacheManager();
  ref.onDispose(() => manager.close());
  return manager;
}

/// 缓存初始化 Provider
@riverpod
Future<void> initCache(Ref ref) async {
  final manager = ref.watch(cacheManagerProvider);
  await manager.init();
}

/// 只同步指定歌单到缓存（不获取歌曲信息）
/// 用于快速刷新单个歌单结构，不更新歌曲详细信息
@riverpod
Future<void> syncSinglePlaylistToCache(Ref ref, String playlistName) async {
  final apiClient = ref.watch(apiClientProvider);
  final cacheManager = ref.watch(cacheManagerProvider);

  try {
    // 获取指定歌单数据
    final playlistResp = await apiClient.getPlaylistMusics(playlistName);

    // 直接保存/更新该歌单的缓存（put 会覆盖已存在的键）
    // 保留其他歌单和歌曲信息缓存不变
    await cacheManager.savePlaylist(playlistName, playlistResp.musics);

    _logger.i('歌单 "$playlistName" 同步完成');
  } catch (e) {
    _logger.e('同步歌单 "$playlistName" 到缓存失败: $e');
    rethrow;
  }
}

/// 只同步歌单列表到缓存（不获取歌曲信息）
/// 用于快速刷新歌单结构，不更新歌曲详细信息
@riverpod
Future<void> syncPlaylistsOnlyToCache(Ref ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final cacheManager = ref.watch(cacheManagerProvider);

  try {
    // 获取所有歌单数据
    final musicList = await apiClient.getMusicList();

    // 只清空歌单缓存，保留歌曲信息缓存
    await cacheManager.clearPlaylists();

    // 保存所有歌单及歌曲到缓存
    await cacheManager.savePlaylists(musicList.playlists);

    _logger.i('歌单列表同步完成');
  } catch (e) {
    _logger.e('同步歌单列表到缓存失败: $e');
    rethrow;
  }
}

/// 同步歌单到缓存 (内部使用，外部请使用 CacheRefreshController)
/// 包含歌单列表和歌曲详细信息
@riverpod
Future<void> syncPlaylistsToCache(Ref ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final cacheManager = ref.watch(cacheManagerProvider);

  try {
    // 获取所有歌单数据
    final musicList = await apiClient.getMusicList();

    // 清空旧缓存以确保同步删除操作
    await cacheManager.clearCache();

    // 保存所有歌单及歌曲到缓存
    await cacheManager.savePlaylists(musicList.playlists);

    // 收集所有歌曲名称（去重）
    final allSongs = <String>{};
    for (final songs in musicList.playlists.values) {
      allSongs.addAll(songs);
    }

    // 分批获取所有歌曲信息（包含 tags）
    // 避免 URL 过长导致连接关闭，每次最多获取 50 首
    if (allSongs.isNotEmpty) {
      try {
        final songNames = allSongs.toList();
        const batchSize = 50; // 每批最多 50 首
        final totalSongs = songNames.length;
        int cachedCount = 0;
        int failedCount = 0;

        // 分批获取
        for (int i = 0; i < songNames.length; i += batchSize) {
          final int end = ((i + batchSize) < songNames.length) ? (i + batchSize) : songNames.length;
          final batch = songNames.sublist(i, end);

          try {
            _logger.i('正在获取歌曲信息 ${i + 1}-$end/$totalSongs...');
            final musicInfos = await apiClient.getMusicInfos(batch, true);

            // 将歌曲信息转换为缓存模型并保存
            final List<SongInfoCache> songInfoCaches = musicInfos.map<SongInfoCache>((info) {
              return SongInfoCache.fromApi(name: info.name, url: info.url, tags: info.tags);
            }).toList();

            await cacheManager.saveSongInfos(songInfoCaches);
            cachedCount += songInfoCaches.length;
          } catch (e) {
            _logger.e("获取第 ${i + 1}-$end 首歌曲信息失败: $e");
            // 单批失败不影响其他批次
            failedCount += batch.length;
          }

          // 添加小延迟，避免请求过快
          if (end < songNames.length) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }

        _logger.i('歌曲信息缓存完成: 成功 $cachedCount 首，失败 $failedCount 首');
      } catch (e) {
        // 如果批量获取歌曲信息失败，不影响歌单缓存
        _logger.e('批量获取歌曲信息失败: $e');
      }
    }
  } catch (e) {
    _logger.e('同步歌单到缓存失败: $e');
    rethrow;
  }
}

/// 手动刷新缓存控制器
/// 负责触发全量刷新，并维护刷新状态（时间戳）
@Riverpod(keepAlive: true)
class CacheRefreshController extends _$CacheRefreshController {
  @override
  Future<DateTime?> build() async {
    await ref.watch(initCacheProvider.future);
    final cacheManager = ref.watch(cacheManagerProvider);
    return cacheManager.getLastUpdateTime();
  }

  /// 强制全量刷新缓存（包括歌单列表和歌曲信息）
  /// 1. 先调用刷新列表接口（发送刷新列表指令）
  /// 2. 获取最新全量数据（歌单 + 歌曲信息）
  /// 3. 更新本地缓存
  /// 4. 更新状态，触发依赖此 Provider 的下游 UI 刷新
  /// 5. 如果播放队列关联了歌单，自动刷新播放队列（通过延迟导入避免循环依赖）
  Future<void> refresh() async {
    state = const AsyncLoading();

    try {
      // 先调用刷新列表接口（发送刷新列表指令）
      final playerStateAsync = ref.read(unifiedPlayerControllerProvider);
      // 获取设备ID：如果有当前设备则使用其did，否则使用默认的web_device
      final did = playerStateAsync.value?.currentDevice?.did ?? BaseConstants.webDevice;
      try {
        final apiClient = ref.read(apiClientProvider);
        await apiClient.sendCmd(DidCmd(did: did, cmd: DeviceCommands.refreshList));
        _logger.i('已调用刷新列表接口，设备ID: $did');
      } catch (e) {
        // 刷新列表接口失败不影响后续同步，只记录日志
        _logger.w('调用刷新列表接口失败: $e');
      }

      // 执行全量同步（包括歌单和歌曲信息）
      await ref.read(syncPlaylistsToCacheProvider.future);

      final cacheManager = ref.read(cacheManagerProvider);
      // 更新状态为最新时间，这将通知监听者
      state = AsyncData(cacheManager.getLastUpdateTime());

      // 如果播放队列关联了歌单，自动刷新播放队列（异步，不阻塞）
      // 使用延迟导入避免循环依赖
      _refreshPlayerQueueIfNeeded(ref);
    } catch (e, st) {
      _logger.e("刷新缓存失败: $e", error: e, stackTrace: st);
      try {
        state = AsyncError(e, st);
      } catch (_) {
        // 忽略 provider 已销毁的情况
        _logger.w("Provider 已销毁，无法更新状态");
      }
    }
  }

  /// 只刷新歌单列表（不刷新歌曲信息）
  /// 用于快速更新歌单结构，如收藏/取消收藏等操作
  /// [playlistName] 可选，如果提供则只刷新指定歌单，否则刷新所有歌单
  /// 1. 先调用刷新列表接口（发送刷新列表指令）
  /// 2. 获取最新歌单数据（不获取歌曲详细信息）
  /// 3. 更新歌单缓存（保留歌曲信息缓存）
  /// 4. 更新状态，触发依赖此 Provider 的下游 UI 刷新
  Future<void> refreshPlaylistsOnly({String? playlistName}) async {
    state = const AsyncLoading();

    try {
      // 先调用刷新列表接口（发送刷新列表指令）
      final playerStateAsync = ref.read(unifiedPlayerControllerProvider);
      // 获取设备ID：如果有当前设备则使用其did，否则使用默认的web_device
      final did = playerStateAsync.value?.currentDevice?.did ?? BaseConstants.webDevice;
      try {
        final apiClient = ref.read(apiClientProvider);
        await apiClient.sendCmd(DidCmd(did: did, cmd: DeviceCommands.refreshList));
        _logger.i('已调用刷新列表接口，设备ID: $did');
      } catch (e) {
        // 刷新列表接口失败不影响后续同步，只记录日志
        _logger.w('调用刷新列表接口失败: $e');
      }

      if (playlistName != null && playlistName.isNotEmpty) {
        // 只同步指定歌单（不获取歌曲信息）
        await ref.read(syncSinglePlaylistToCacheProvider(playlistName).future);
        _logger.i('已刷新歌单: $playlistName');
      } else {
        // 只同步所有歌单列表（不获取歌曲信息）
        await ref.read(syncPlaylistsOnlyToCacheProvider.future);
      }

      final cacheManager = ref.read(cacheManagerProvider);
      // 更新状态为最新时间，这将通知监听者
      // 注意：cachedPlaylistSongsProvider 已经 watch 了 cacheRefreshControllerProvider，
      // 所以当状态更新时会自动重新计算，无需手动 invalidate
      state = AsyncData(cacheManager.getLastUpdateTime());

      // 如果播放队列关联了歌单，自动刷新播放队列（异步，不阻塞）
      // 使用延迟导入避免循环依赖
      _refreshPlayerQueueIfNeeded(ref);
    } catch (e, st) {
      _logger.e("刷新歌单列表失败: $e", error: e, stackTrace: st);
      try {
        state = AsyncError(e, st);
      } catch (_) {
        // 忽略 provider 已销毁的情况
        _logger.w("Provider 已销毁，无法更新状态");
      }
    }
  }

  /// 检查并刷新播放队列（如果关联了歌单）
  /// 注意：这里访问 unifiedPlayerControllerProvider 会造成循环依赖
  /// 但通过 ref.read 访问是运行时行为，不会有编译时问题
  void _refreshPlayerQueueIfNeeded(Ref ref) {
    // 异步执行，不阻塞缓存刷新
    Future.microtask(() async {
      try {
        final playerStateAsync = ref.read(unifiedPlayerControllerProvider);
        if (!playerStateAsync.hasValue) return;

        final playerState = playerStateAsync.value;
        if (playerState?.currentPlaylistName != null && playerState!.currentPlaylistName!.isNotEmpty) {
          // 从缓存刷新播放队列
          ref.read(unifiedPlayerControllerProvider.notifier).refreshCurrentPlaylist();
        }
      } catch (e) {
        // 忽略错误，不影响缓存刷新
        _logger.e("刷新播放队列失败: $e");
      }
    });
  }
}

/// 从缓存获取歌单名称列表
@riverpod
Future<List<String>> cachedPlaylistNames(Ref ref) async {
  // 监听刷新控制器，当刷新完成后自动重新获取
  ref.watch(cacheRefreshControllerProvider);

  // 确保缓存已初始化
  await ref.watch(initCacheProvider.future);

  final cacheManager = ref.watch(cacheManagerProvider);

  // 如果没有缓存，尝试初次同步
  if (!cacheManager.hasCache) {
    try {
      await ref.watch(syncPlaylistsToCacheProvider.future);
    } catch (e) {
      // 忽略初次同步失败，返回空列表或旧缓存
      _logger.w("初次同步缓存失败: $e");
    }
  }

  return cacheManager.getAllPlaylistNames();
}

/// 从缓存获取指定歌单的歌曲
@Riverpod(keepAlive: true)
Future<List<String>> cachedPlaylistSongs(Ref ref, String playlistName) async {
  // 监听刷新控制器，当刷新完成后自动重新获取
  ref.watch(cacheRefreshControllerProvider);

  // 确保缓存已初始化
  await ref.watch(initCacheProvider.future);

  final cacheManager = ref.watch(cacheManagerProvider);
  final cache = cacheManager.getPlaylist(playlistName);

  if (cache == null) {
    // 缓存中没有，可能是新歌单或者缓存被清空
    // 注意：getMusicList 才是全量接口，但这里为了单个查询兼容性保留逻辑
    // 实际上如果上游 refresh 正常，这里应该能从缓存读到
    // 如果读不到，说明真的不存在，或者 API 结构变更

    // 尝试获取全量列表来修复（因为不支持单歌单查询）
    // 但为了避免死循环，这里只返回空列表
    return [];
  }

  return cache.songs;
}

/// 从缓存搜索歌曲
@riverpod
Future<List<String>> cachedSearchSongs(Ref ref, String query, {String? playlistName}) async {
  ref.watch(cacheRefreshControllerProvider);

  await ref.watch(initCacheProvider.future);
  final cacheManager = ref.watch(cacheManagerProvider);

  return cacheManager.searchSongs(query, playlistName: playlistName);
}

/// 从缓存获取歌曲信息
@riverpod
SongInfoCache? cachedSongInfo(Ref ref, String songName) {
  ref.watch(cacheRefreshControllerProvider);

  final cacheManager = ref.watch(cacheManagerProvider);
  return cacheManager.getSongInfo(songName);
}

/// 批量从缓存获取歌曲信息
@riverpod
Map<String, SongInfoCache> cachedSongInfos(Ref ref, List<String> songNames) {
  ref.watch(cacheRefreshControllerProvider);

  final cacheManager = ref.watch(cacheManagerProvider);
  return cacheManager.getSongInfos(songNames);
}
