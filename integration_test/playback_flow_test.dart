import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mi_music/core/testing/app_test_config.dart';
import 'package:mi_music/main.dart' as app;
import 'package:mi_music/presentation/widgets/integration_test_probe.dart';
import 'package:mi_music/presentation/widgets/song_title_text.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('播放链路自动化验证', (tester) async {
    app.main();
    await _pumpFor(tester, const Duration(seconds: 3));

    await _loginIfNeeded(tester);
    await _waitForLibraryPage(tester);
    await _openTargetPlaylist(tester);
    final firstSong = await _playTargetSong(tester);

    await _waitForPlaybackStarted(tester);
    expect(_probeText(tester, IntegrationTestProbe.isLocalModeKey), 'true');

    await _openFullPlayer(tester);
    await _verifyPauseResume(tester);
    await _verifySeekWorks(tester);
    await _verifyQueueNavigation(tester, firstSong);
  });
}

Future<void> _loginIfNeeded(WidgetTester tester) async {
  if (!_exists(find.byKey(const Key('login-page')))) {
    return;
  }

  final serverUrl = AppTestConfig.serverUrl.trim();
  if (serverUrl.isEmpty) {
    fail('缺少登录态，且未传入 MI_MUSIC_TEST_SERVER_URL，无法自动登录。');
  }

  await tester.enterText(
    find.byKey(const Key('login-server-url-field')),
    serverUrl,
  );
  await tester.enterText(
    find.byKey(const Key('login-username-field')),
    AppTestConfig.username,
  );
  await tester.enterText(
    find.byKey(const Key('login-password-field')),
    AppTestConfig.password,
  );
  await tester.tap(find.byKey(const Key('login-connect-button')));
  await _pumpFor(tester, const Duration(seconds: 3));
}

Future<void> _waitForLibraryPage(WidgetTester tester) async {
  await _waitUntil(
    tester,
    () => _exists(find.byKey(const Key('library-page'))),
    timeout: const Duration(seconds: 30),
    reason: '首页音乐库未加载完成',
  );
  await _waitUntil(
    tester,
    () => _exists(find.byKey(const ValueKey('playlist-tile-0'))),
    timeout: const Duration(seconds: 30),
    reason: '未发现可用歌单',
  );
}

Future<void> _openTargetPlaylist(WidgetTester tester) async {
  if (AppTestConfig.hasPlaylistName) {
    final playlistFinder = find.text(AppTestConfig.playlistName.trim());
    await _waitUntil(
      tester,
      () => _exists(playlistFinder),
      timeout: const Duration(seconds: 20),
      reason: '未找到指定歌单 ${AppTestConfig.playlistName}',
    );
    await tester.tap(playlistFinder.first);
    await _pumpFor(tester, const Duration(seconds: 2));
    await _waitUntil(
      tester,
      () => _exists(find.byKey(const Key('playlist-detail-page'))),
      timeout: const Duration(seconds: 20),
      reason: '歌单详情页未打开',
    );
    await _waitUntil(
      tester,
      () => _exists(find.byKey(const ValueKey('song-row-0'))),
      timeout: const Duration(seconds: 20),
      reason: '指定歌单内未发现歌曲',
    );
    return;
  }

  for (var index = 0; index < 20; index++) {
    final tileFinder = find.byKey(ValueKey('playlist-tile-$index'));
    if (!_exists(tileFinder)) {
      break;
    }

    await tester.tap(tileFinder);
    await _pumpFor(tester, const Duration(seconds: 2));
    await _waitUntil(
      tester,
      () => _exists(find.byKey(const Key('playlist-detail-page'))),
      timeout: const Duration(seconds: 20),
      reason: '歌单详情页未打开',
    );

    final hasSongs = await _waitUntilOptional(
      tester,
      () => _exists(find.byKey(const ValueKey('song-row-0'))),
      timeout: const Duration(seconds: 5),
    );
    if (hasSongs) {
      return;
    }

    await _navigateBack(tester);
    await _pumpFor(tester, const Duration(seconds: 2));
    await _waitUntil(
      tester,
      () => _exists(find.byKey(const Key('library-page'))),
      timeout: const Duration(seconds: 20),
      reason: '返回音乐库失败',
    );
  }

  fail('未找到包含歌曲的可播放歌单');
}

Future<String> _playTargetSong(WidgetTester tester) async {
  Finder songRowFinder;
  Finder songTitleFinder;

  if (AppTestConfig.hasSongName) {
    songRowFinder = find.ancestor(
      of: find.text(AppTestConfig.songName.trim()),
      matching: find.byType(InkWell),
    );
    songTitleFinder = find.text(AppTestConfig.songName.trim());
  } else {
    songRowFinder = find.byKey(const ValueKey('song-row-0'));
    songTitleFinder = find.byKey(const ValueKey('song-title-0'));
  }

  await _waitUntil(
    tester,
    () => _exists(songRowFinder),
    timeout: const Duration(seconds: 20),
    reason: '目标歌曲不存在或未渲染完成',
  );

  final songTitle = _readTextFromFinder(tester, songTitleFinder);
  await tester.tap(songRowFinder.first);
  await _pumpFor(tester, const Duration(seconds: 2));
  return songTitle;
}

Future<void> _waitForPlaybackStarted(WidgetTester tester) async {
  await _waitUntil(
    tester,
    () => _probeText(tester, IntegrationTestProbe.isPlayingKey) == 'true',
    timeout: const Duration(seconds: 45),
    reason: '播放器未进入播放态',
  );

  await _waitUntil(
    tester,
    () => _probeInt(tester, IntegrationTestProbe.durationMsKey) > 0,
    timeout: const Duration(seconds: 45),
    reason: '播放器未拿到音频时长',
  );

  await _waitUntil(
    tester,
    () => _probeInt(tester, IntegrationTestProbe.positionMsKey) > 0,
    timeout: const Duration(seconds: 45),
    reason: '播放进度未推进，疑似未真正出声',
  );
}

Future<void> _openFullPlayer(WidgetTester tester) async {
  await _waitUntil(
    tester,
    () => _exists(find.byKey(const Key('mini-player'))),
    timeout: const Duration(seconds: 20),
    reason: '迷你播放器未出现',
  );
  await tester.tap(find.byKey(const Key('mini-player')));
  await _pumpFor(tester, const Duration(seconds: 2));
  await _waitUntil(
    tester,
    () => _exists(find.byKey(const Key('full-player-page'))),
    timeout: const Duration(seconds: 20),
    reason: '全屏播放器未打开',
  );
}

Future<void> _verifyPauseResume(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('full-player-play-pause-button')));
  await _pumpFor(tester, const Duration(seconds: 1));
  await _waitUntil(
    tester,
    () => _probeText(tester, IntegrationTestProbe.isPlayingKey) == 'false',
    timeout: const Duration(seconds: 15),
    reason: '暂停后播放器状态未切换',
  );

  await tester.tap(find.byKey(const Key('full-player-play-pause-button')));
  await _pumpFor(tester, const Duration(seconds: 1));
  await _waitUntil(
    tester,
    () => _probeText(tester, IntegrationTestProbe.isPlayingKey) == 'true',
    timeout: const Duration(seconds: 15),
    reason: '恢复播放后播放器状态未切换',
  );
}

Future<void> _verifySeekWorks(WidgetTester tester) async {
  final durationMs = _probeInt(tester, IntegrationTestProbe.durationMsKey);
  if (durationMs < 15000) {
    return;
  }

  final beforeSeekPosition = _probeInt(tester, IntegrationTestProbe.positionMsKey);
  final sliderFinder = find.byKey(const Key('full-player-progress-slider'));
  final sliderRect = tester.getRect(sliderFinder);
  final targetOffset = Offset(
    sliderRect.left + sliderRect.width * 0.7,
    sliderRect.center.dy,
  );

  await tester.tapAt(targetOffset);
  await _pumpFor(tester, const Duration(seconds: 2));

  await _waitUntil(
    tester,
    () => _probeInt(tester, IntegrationTestProbe.positionMsKey) >
        beforeSeekPosition + 5000,
    timeout: const Duration(seconds: 15),
    reason: '拖动进度条后播放位置未明显变化',
  );
}

Future<void> _verifyQueueNavigation(
  WidgetTester tester,
  String firstSong,
) async {
  final playlistLength = _probeInt(
    tester,
    IntegrationTestProbe.playlistLengthKey,
  );
  if (playlistLength < 2) {
    return;
  }

  final originalSong = _probeText(tester, IntegrationTestProbe.currentSongKey);
  await tester.tap(find.byKey(const Key('full-player-skip-next-button')));
  await _pumpFor(tester, const Duration(seconds: 2));

  await _waitUntil(
    tester,
    () => _probeText(tester, IntegrationTestProbe.currentSongKey) != originalSong,
    timeout: const Duration(seconds: 20),
    reason: '下一首后当前歌曲未变化',
  );

  await tester.tap(find.byKey(const Key('full-player-skip-previous-button')));
  await _pumpFor(tester, const Duration(seconds: 2));

  await _waitUntil(
    tester,
    () {
      final currentSong = _probeText(
        tester,
        IntegrationTestProbe.currentSongKey,
      );
      return currentSong == originalSong || currentSong == firstSong;
    },
    timeout: const Duration(seconds: 20),
    reason: '上一首后未回到原歌曲',
  );
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  required String reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (condition()) {
      return;
    }
  }

  fail(reason);
}

Future<bool> _waitUntilOptional(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (condition()) {
      return true;
    }
  }

  return false;
}

Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final steps = duration.inMilliseconds ~/ 200;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _navigateBack(WidgetTester tester) async {
  final backButtonFinder = find.byType(BackButton);
  if (_exists(backButtonFinder)) {
    await tester.tap(backButtonFinder.first);
    return;
  }

  final arrowBackFinder = find.byIcon(Icons.arrow_back);
  if (_exists(arrowBackFinder)) {
    await tester.tap(arrowBackFinder.first);
    return;
  }

  fail('当前页面未找到可点击的返回按钮');
}

bool _exists(Finder finder) => finder.evaluate().isNotEmpty;

String _probeText(WidgetTester tester, Key key) {
  final finder = find.byKey(key, skipOffstage: false);
  if (!_exists(finder)) {
    return '';
  }
  return _readTextFromFinder(tester, finder);
}

int _probeInt(WidgetTester tester, Key key) {
  return int.tryParse(_probeText(tester, key)) ?? 0;
}

String _readTextFromFinder(WidgetTester tester, Finder finder) {
  final widget = tester.widget(finder.first);
  if (widget is Text) {
    final data = widget.data;
    if (data != null) {
      return data;
    }
    return widget.textSpan?.toPlainText() ?? '';
  }
  if (widget is SongTitleText) {
    return widget.text;
  }
  fail('无法从 ${widget.runtimeType} 读取文本');
}
