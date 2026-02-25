import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/breakpoints.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/presentation/pages/settings/sections/account_section.dart';
import 'package:mi_music/presentation/pages/settings/sections/directory_section.dart';
import 'package:mi_music/presentation/pages/settings/sections/service_section.dart';
import 'package:mi_music/presentation/pages/settings/sections/play_section.dart';
import 'package:mi_music/presentation/pages/settings/sections/voice_control_section.dart';
import 'package:mi_music/presentation/pages/settings/sections/dialog_tts_section.dart';

/// 设置页面主页（支持响应式布局）
/// [initialSection] 可选，用于从路由跳转时直接打开指定 section，如 'service' 表示服务配置
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.initialSection});

  /// 路由 query 的 section 名：account | directory | service | play | voice | dialog
  final String? initialSection;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _sectionToIndex = {
    'account': 0,
    'directory': 1,
    'service': 2,
    'play': 3,
    'voice': 4,
    'dialog': 5,
  };

  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSection != null
        ? (_sectionToIndex[widget.initialSection] ?? 0).clamp(0, 5)
        : 0;
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialSectionIfMobile());
    }
  }

  void _openInitialSectionIfMobile() {
    if (!mounted) return;
    if (MediaQuery.sizeOf(context).width >= Breakpoints.navRail) return;
    final index = _sectionToIndex[widget.initialSection!] ?? 0;
    if (index < 0 || index >= _categories.length) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(_categories[index].title)),
          body: _categories[index].widget,
        ),
      ),
    );
  }

  final List<_SettingCategory> _categories = [
    _SettingCategory(
      icon: Icons.account_circle_rounded,
      title: S.accountSettings,
      widget: const AccountSection(),
    ),
    _SettingCategory(
      icon: Icons.folder_rounded,
      title: S.directorySettings,
      widget: const DirectorySection(),
    ),
    _SettingCategory(
      icon: Icons.arrow_forward_rounded,
      title: S.serviceSettings,
      widget: const ServiceSection(),
    ),
    _SettingCategory(
      icon: Icons.play_circle_rounded,
      title: S.playSettings,
      widget: const PlaySection(),
    ),
    _SettingCategory(
      icon: Icons.mic_rounded,
      title: S.voiceSettings,
      widget: const VoiceControlSection(),
    ),
    _SettingCategory(
      icon: Icons.chat_bubble_rounded,
      title: S.dialogSettings,
      widget: const DialogTtsSection(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 大屏：左右分栏布局
        if (constraints.maxWidth >= Breakpoints.navRail) {
          return _buildDesktopLayout(context);
        }
        // 小屏：单列布局
        return _buildMobileLayout(context);
      },
    );
  }

  /// 桌面/平板布局（左右分栏）
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: Row(
        children: [
          // 左侧导航（可滚动）
          SizedBox(
            width: 200,
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              leading: const SizedBox(height: 16),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      '${_selectedIndex + 1} / ${_categories.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
              destinations: _categories.map((category) {
                return NavigationRailDestination(
                  icon: Icon(category.icon),
                  selectedIcon: Icon(category.icon),
                  label: Text(
                    category.title,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // 右侧内容（可滚动）
          Expanded(
            child: SingleChildScrollView(
              child: _categories[_selectedIndex].widget,
            ),
          ),
        ],
      ),
    );
  }

  /// 移动端布局（分类卡片列表）
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.settings)),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Icon(category.icon, size: 28),
              title: Text(category.title),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: Text(category.title)),
                      body: category.widget,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// 设置分类模型
class _SettingCategory {
  final IconData icon;
  final String title;
  final Widget widget;

  const _SettingCategory({
    required this.icon,
    required this.title,
    required this.widget,
  });
}
