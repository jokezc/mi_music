import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/presentation/widgets/mini_player.dart';

/// 带底部导航栏的 Scaffold 壳
/// 包含3个Tab：音乐库、搜索、功能
/// 以及悬浮在导航栏上方的迷你播放条
class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 迷你播放条
          const MiniPlayer(),
          // 底部导航栏
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (int index) {
              navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: S.navLibrary,
              ),
              NavigationDestination(
                icon: Icon(Icons.arrow_circle_down),
                selectedIcon: Icon(Icons.download_for_offline),
                label: S.download,
              ),
              NavigationDestination(
                icon: Icon(Icons.widgets_outlined),
                selectedIcon: Icon(Icons.widgets),
                label: S.navFunctions,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
