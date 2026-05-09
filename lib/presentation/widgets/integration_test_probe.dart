import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/data/providers/player/player_provider.dart';

class IntegrationTestProbe extends ConsumerWidget {
  const IntegrationTestProbe({super.key});

  static const currentSongKey = Key('probe-current-song');
  static const isPlayingKey = Key('probe-is-playing');
  static const isLocalModeKey = Key('probe-is-local-mode');
  static const positionMsKey = Key('probe-position-ms');
  static const durationMsKey = Key('probe-duration-ms');
  static const currentIndexKey = Key('probe-current-index');
  static const playlistLengthKey = Key('probe-playlist-length');
  static const currentPlaylistKey = Key('probe-current-playlist');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(unifiedPlayerControllerProvider);
    final playerState = playerAsync.value;

    return IgnorePointer(
      child: Opacity(
        opacity: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(playerState?.currentSong ?? '', key: currentSongKey),
            Text('${playerState?.isPlaying ?? false}', key: isPlayingKey),
            Text('${playerState?.isLocalMode ?? false}', key: isLocalModeKey),
            Text(
              '${playerState?.position.inMilliseconds ?? 0}',
              key: positionMsKey,
            ),
            Text(
              '${playerState?.duration.inMilliseconds ?? 0}',
              key: durationMsKey,
            ),
            Text('${playerState?.currentIndex ?? -1}', key: currentIndexKey),
            Text(
              '${playerState?.playlist.length ?? 0}',
              key: playlistLengthKey,
            ),
            Text(
              playerState?.currentPlaylistName ?? '',
              key: currentPlaylistKey,
            ),
          ],
        ),
      ),
    );
  }
}
