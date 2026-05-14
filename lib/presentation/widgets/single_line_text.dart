import 'package:flutter/material.dart';
import 'package:mi_music/presentation/widgets/overflow_marquee_text.dart';

/// 通用单行文本组件。
/// 默认单行省略；在需要时可开启跑马灯，但不承载具体业务语义。
class SingleLineText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool enableMarquee;
  final double gap;
  final Duration speedPer100Px;

  const SingleLineText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.enableMarquee = false,
    this.gap = 20,
    this.speedPer100Px = const Duration(milliseconds: 3200),
  });

  @override
  Widget build(BuildContext context) {
    if (enableMarquee) {
      return OverflowMarqueeText(
        text: text,
        style: style,
        textAlign: textAlign,
        gap: gap,
        speedPer100Px: speedPer100Px,
      );
    }

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}
