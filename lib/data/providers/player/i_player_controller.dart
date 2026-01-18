import 'package:mi_music/data/providers/player/player_state.dart';

/// 播放控制器抽象类，定义统一接口
abstract class IPlayerController {
  Future<PlayerState> getState();
  Future<void> playSong(String songName, {String? playlistName});
  Future<void> playPlaylistByName(String playlistName);
  Future<void> playFromQueueIndex(int index);
  Future<void> playPause();
  Future<void> skipNext();
  Future<void> skipPrevious();
  Future<void> seek(Duration position);
  Future<void> toggleLoopMode();
  Future<void> toggleShuffleMode();
  Future<void> togglePlayMode();
  Future<void> setVolume(int volume);
  Future<void> sendShutdownCommand(int minutes);

  /// 设置状态更新回调（用于实时同步状态）
  Future<void> setStateUpdateCallback(void Function(PlayerState) callback);

  /// 清理资源
  Future<void> dispose();
}

