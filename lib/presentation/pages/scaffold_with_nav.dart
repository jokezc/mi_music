import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mi_music/core/constants/breakpoints.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/presentation/widgets/mini_player.dart';

/// 带导航的 Scaffold 壳
/// - 窄屏（手机）：底部导航栏 + 迷你播放条
/// - 宽屏（平板/桌面）：左侧 NavigationRail + 内容区最大宽度 + 底部迷你播放条
class ScaffoldWithNav extends StatelessWidget {
  const ScaffoldWithNav({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.library_music_rounded, selectedIcon: Icons.library_music_rounded, label: S.navLibrary),
    (icon: Icons.arrow_circle_down_rounded, selectedIcon: Icons.download_for_offline_rounded, label: S.download),
    (icon: Icons.widgets_rounded, selectedIcon: Icons.widgets_rounded, label: S.navFunctions),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= Breakpoints.navRail;
        if (useRail) {
          return _buildDesktopLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (int index) {
              navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
            },
            destinations: [
              NavigationDestination(
                icon: Icon(_destinations[0].icon),
                selectedIcon: Icon(_destinations[0].icon),
                label: _destinations[0].label,
              ),
              NavigationDestination(
                icon: Icon(_destinations[1].icon),
                selectedIcon: Icon(_destinations[1].selectedIcon),
                label: _destinations[1].label,
              ),
              NavigationDestination(
                icon: Icon(_destinations[2].icon),
                selectedIcon: Icon(_destinations[2].icon),
                label: _destinations[2].label,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: (int index) {
                    navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(_destinations[0].icon),
                      selectedIcon: Icon(_destinations[0].icon),
                      label: Text(_destinations[0].label),
                    ),
                    NavigationRailDestination(
                      icon: Icon(_destinations[1].icon),
                      selectedIcon: Icon(_destinations[1].selectedIcon),
                      label: Text(_destinations[1].label),
                    ),
                    NavigationRailDestination(
                      icon: Icon(_destinations[2].icon),
                      selectedIcon: Icon(_destinations[2].icon),
                      label: Text(_destinations[2].label),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
                      child: navigationShell,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const MiniPlayer(),
        ],
      ),
    );
  }
}
