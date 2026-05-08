import 'package:flutter/material.dart';

/// 更紧凑、可控的歌曲行布局，避免 ListTile 对两行标题的垂直约束裁切。
class SongRowLayout extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double height;
  final double horizontalPadding;
  final double gap;

  const SongRowLayout({
    super.key,
    required this.leading,
    required this.title,
    this.trailing,
    this.onTap,
    this.height = 56,
    this.horizontalPadding = 16,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          children: [
            leading,
            SizedBox(width: gap),
            Expanded(child: title),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
