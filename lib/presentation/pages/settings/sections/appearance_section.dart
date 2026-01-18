import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mi_music/core/constants/strings_zh.dart';
import 'package:mi_music/data/providers/theme_provider.dart';

/// 外观设置 Section
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.appearanceSettings,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Card(
            child: RadioGroup<AppThemeMode>(
              groupValue: themeMode,
              onChanged: (value) {
                if (value != null) {
                  ref
                      .read(themeControllerProvider.notifier)
                      .setThemeMode(value);
                }
              },
              child: Column(
                children: AppThemeMode.values.map((mode) {
                  return RadioListTile<AppThemeMode>(
                    value: mode,
                    title: Text(mode.displayName),
                    subtitle: Text(_getSubtitle(mode)),
                    secondary: Icon(mode.icon),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '主题预览',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const _ThemePreviewCard(),
        ],
      ),
    );
  }

  String _getSubtitle(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return '根据系统设置自动切换';
      case AppThemeMode.light:
        return '始终使用浅色主题';
      case AppThemeMode.dark:
        return '始终使用深色主题';
    }
  }
}

/// 主题预览卡片
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '预览歌曲标题',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text('艺术家 • 专辑', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0.6,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1:23', style: theme.textTheme.bodySmall),
                Text('3:45', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                isDark ? '当前：深色主题' : '当前：浅色主题',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
