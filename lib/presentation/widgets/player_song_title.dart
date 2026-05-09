import 'package:flutter/material.dart';

/// 全屏播放页使用的主标题。
/// 最多展示两行，超出后省略，保持主视觉稳定。
class PlayerSongTitle extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double height;

  const PlayerSongTitle({
    super.key,
    required this.text,
    this.style,
    this.height = 68,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = DefaultTextStyle.of(context).style;
    final resolvedStyle = (style ?? defaultStyle).copyWith(height: 1.16);

    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          text,
          style: resolvedStyle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          strutStyle: StrutStyle(
            fontSize: resolvedStyle.fontSize,
            height: resolvedStyle.height,
            leading: 0,
            forceStrutHeight: true,
          ),
        ),
      ),
    );
  }
}
