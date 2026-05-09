import 'package:flutter/material.dart';

/// 列表/设备场景使用的单行歌曲名。
/// 不换行、不缩小，超出直接省略，保证扫读节奏稳定。
class SongTitleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const SongTitleText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
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
