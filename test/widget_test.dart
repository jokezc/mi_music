// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mi_music/main.dart';
import 'package:mi_music/data/providers/shared_prefs_provider.dart';
import 'package:mi_music/data/providers/cache_provider.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    // Riverpod + SharedPreferences mock
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // 测试环境不跑缓存初始化/后台同步，避免依赖网络与平台通道
          initCacheProvider.overrideWith((ref) async {}),
          syncPlaylistsToCacheProvider.overrideWith((ref) async {}),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
