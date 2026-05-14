import 'package:flutter/material.dart';
import 'package:mi_music/presentation/widgets/single_line_text.dart';

/// 歌曲标题组件。
/// 统一歌曲名在列表、迷你播放栏、全屏播放页中的单行显示策略。
class SongTitleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool enableMarquee;
  final double gap;
  final Duration speedPer100Px;

  const SongTitleText({
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
    return SingleLineText(
      text: text,
      style: style,
      textAlign: textAlign,
      enableMarquee: enableMarquee,
      gap: gap,
      speedPer100Px: speedPer100Px,
    );
  }
}
