import 'dart:convert';

import 'package:just_audio/just_audio.dart' hide PlayerState;
import 'package:mi_music/data/models/api_models.dart';

/// 播放器通用状态
class PlayerState {
  final bool isPlaying; // 当前是否在播放
  final Duration position; // 当前播放进度
  final Duration duration; // 当前音频总时长
  final String? currentSong; // 当前播放的歌曲标识/名称
  final LoopMode loopMode; // 循环模式：off/one/all
  final bool shuffleMode; // 是否启用随机播放
  final Device? currentDevice; // 当前播放设备（本地/远程）
  final String? currentPlaylistName; // 当前歌单名称（便于语义化队列）
  final List<String> playlist; // 当前播放队列（歌曲名列表）
  final int currentIndex; // 当前队列索引

  const PlayerState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.currentSong,
    this.loopMode = LoopMode.off,
    this.shuffleMode = false,
    this.currentDevice,
    this.currentPlaylistName,
    List<String>? playlist,
    this.currentIndex = -1,
  }) : playlist = playlist ?? const [];

  /// 判断是否为本地模式
  bool get isLocalMode => currentDevice?.type == DeviceType.local;

  /// 判断是否为远程模式
  bool get isRemoteMode => currentDevice?.type == DeviceType.remote;

  /// 转换为 Map，支持忽略指定字段
  ///
  /// [ignoreFields] 要忽略的字段名集合，例如 {'playlist', 'currentDevice'}
  Map<String, dynamic> toMap({Set<String>? ignoreFields}) {
    final ignore = ignoreFields ?? <String>{};
    final json = <String, dynamic>{};

    if (!ignore.contains('isPlaying')) {
      json['isPlaying'] = isPlaying;
    }
    if (!ignore.contains('position')) {
      json['position'] = position.inSeconds;
    }
    if (!ignore.contains('duration')) {
      json['duration'] = duration.inSeconds;
    }
    if (!ignore.contains('currentSong')) {
      json['currentSong'] = currentSong;
    }
    if (!ignore.contains('loopMode')) {
      json['loopMode'] = loopMode.index;
    }
    if (!ignore.contains('shuffleMode')) {
      json['shuffleMode'] = shuffleMode;
    }
    if (!ignore.contains('currentDevice')) {
      json['currentDevice'] = currentDevice?.toJson();
    }
    if (!ignore.contains('currentPlaylistName')) {
      json['currentPlaylistName'] = currentPlaylistName;
    }
    if (!ignore.contains('playlist')) {
      json['playlist'] = playlist;
    }
    if (!ignore.contains('currentIndex')) {
      json['currentIndex'] = currentIndex;
    }

    return json;
  }

  /// 转换为 Map，忽略 playlist 字段
  ///
  /// 基于 [toMap] 方法实现，便捷方法
  Map<String, dynamic> toMapIgnorePlaylist() {
    return toMap(ignoreFields: {'playlist'});
  }

  /// 转换为 JSON 字符串，支持忽略指定字段
  ///
  /// [ignoreFields] 要忽略的字段名集合，例如 {'playlist', 'currentDevice'}
  String toJson({Set<String>? ignoreFields}) {
    return jsonEncode(toMap(ignoreFields: ignoreFields));
  }

  /// 转换为 JSON 字符串，忽略 playlist 字段
  ///
  /// 基于 [toJson] 方法实现，便捷方法
  String toJsonIgnorePlaylist() {
    return toJson(ignoreFields: {'playlist'});
  }

  PlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? currentSong,
    LoopMode? loopMode,
    bool? shuffleMode,
    Device? currentDevice,
    String? currentPlaylistName,
    List<String>? playlist,
    int? currentIndex,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      currentSong: currentSong ?? this.currentSong,
      loopMode: loopMode ?? this.loopMode,
      shuffleMode: shuffleMode ?? this.shuffleMode,
      currentDevice: currentDevice ?? this.currentDevice,
      currentPlaylistName: currentPlaylistName ?? this.currentPlaylistName,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}
