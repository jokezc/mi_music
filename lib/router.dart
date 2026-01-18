import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mi_music/data/models/api_models.dart';
import 'package:mi_music/data/providers/api_provider.dart';
import 'package:mi_music/data/providers/settings_provider.dart';
import 'package:mi_music/presentation/pages/download/download_page.dart';
import 'package:mi_music/presentation/pages/functions/connection_page.dart';
import 'package:mi_music/presentation/pages/functions/cron_task_edit_page.dart';
import 'package:mi_music/presentation/pages/functions/cron_task_list_page.dart';
import 'package:mi_music/presentation/pages/functions/functions_page.dart';
import 'package:mi_music/presentation/pages/library/library_page.dart';
import 'package:mi_music/presentation/pages/login_page.dart';
import 'package:mi_music/presentation/pages/player/full_player_page.dart';
import 'package:mi_music/presentation/pages/playlist/playlist_detail_page.dart';
import 'package:mi_music/presentation/pages/scaffold_with_nav.dart';
import 'package:mi_music/presentation/pages/search/search_page.dart';
import 'package:mi_music/presentation/pages/settings/about_page.dart';
import 'package:mi_music/presentation/pages/settings/appearance_page.dart';
import 'package:mi_music/presentation/pages/settings/client_settings_page.dart';
import 'package:mi_music/presentation/pages/settings/settings_page.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

final _logger = Logger();

@riverpod
GoRouter router(Ref ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();

  // 监听认证状态，当状态改变时 router 会重建，redirect 会重新执行
  ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/client-settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ClientSettingsPage(),
      ),
      GoRoute(path: '/about', parentNavigatorKey: rootNavigatorKey, builder: (context, state) => const AboutPage()),
      GoRoute(
        path: '/appearance',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AppearancePage(),
      ),
      GoRoute(
        path: '/player',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const FullPlayerPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/connection-config',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ConnectionPage(),
      ),
      GoRoute(
        path: '/cron-task/list',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CronTaskListPage(),
      ),
      GoRoute(
        path: '/cron-task/edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final task = extra?['task'] as CronTask?;
          final index = extra?['index'] as int? ?? -1;
          return CronTaskEditPage(task: task, index: index);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) {
          final playlistName = state.uri.queryParameters['playlist'];
          final initialQuery = state.uri.queryParameters['q'];
          return SearchPage(playlistName: playlistName, initialQuery: initialQuery);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNav(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: 音乐库 (主页)
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (context, state) => const LibraryPage()),
              GoRoute(
                path: '/playlist/:name',
                builder: (context, state) {
                  final encodedName = state.pathParameters['name']!;
                  // 安全解码，如果解码失败则使用原始值
                  String name;
                  try {
                    name = Uri.decodeComponent(encodedName);
                  } catch (e) {
                    _logger.e("解码歌单名称 $encodedName 失败: $e");
                    // 如果解码失败（例如包含无效的百分号编码），使用原始值
                    name = encodedName;
                  }
                  return PlaylistDetailPage(playlistName: name);
                },
              ),
            ],
          ),
          // Tab 2: 下载
          StatefulShellBranch(
            routes: [GoRoute(path: '/download', builder: (context, state) => const DownloadPage())],
          ),
          // Tab 3: 功能
          StatefulShellBranch(
            routes: [GoRoute(path: '/functions', builder: (context, state) => const FunctionsPage())],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      // 在 redirect 函数中读取 settings 和认证状态，而不是在 build 时 watch
      // 这样可以避免 settings 更新时导致 router 重建
      final settings = ref.read(settingsProvider);
      final isLoggedIn = settings.serverUrl.isNotEmpty;
      final isAuthorized = ref.read(authStateProvider);
      final isLoginRoute = state.uri.toString() == '/login';

      // 如果未配置服务器地址或认证失效，跳转到登录页
      if ((!isLoggedIn || !isAuthorized) && !isLoginRoute) {
        return '/login';
      }

      // 如果已登录且已认证，但在登录页，跳转到首页
      if (isLoggedIn && isAuthorized && isLoginRoute) {
        return '/';
      }

      return null;
    },
  );
}
