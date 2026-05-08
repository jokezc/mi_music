import 'package:flutter/material.dart';

/// 固定高度的歌曲标题：
/// 1. 先尝试通过缩小字号保持单行显示
/// 2. 单行仍放不下时，再切换为两行显示
/// 3. 始终占用固定高度，避免因换行导致布局抖动
class AdaptiveSongTitle extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int wrappedMaxLines;
  final double singleLineMinFontSize;
  final double wrappedMinFontSize;
  final double? fixedHeight;

  const AdaptiveSongTitle({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.wrappedMaxLines = 2,
    this.singleLineMinFontSize = 14,
    this.wrappedMinFontSize = 12,
    this.fixedHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultStyle = DefaultTextStyle.of(context).style;
        final baseStyle = style ?? defaultStyle;
        final direction = Directionality.of(context);
        final baseFontSize = baseStyle.fontSize ?? 14;
        final resolvedHeight = fixedHeight ?? (_lineHeight(baseStyle, baseFontSize) * wrappedMaxLines) + 4;

        final singleLineFontSize = _findLargestFittingFontSize(
          text: text,
          maxWidth: constraints.maxWidth,
          textDirection: direction,
          baseStyle: baseStyle,
          baseFontSize: baseFontSize,
          minFontSize: singleLineMinFontSize,
          maxLines: 1,
        );

        final bool useWrappedLayout;
        final double resolvedFontSize;

        if (singleLineFontSize != null) {
          useWrappedLayout = false;
          resolvedFontSize = singleLineFontSize;
        } else {
          useWrappedLayout = true;
          resolvedFontSize =
              _findLargestFittingFontSize(
                text: text,
                maxWidth: constraints.maxWidth,
                textDirection: direction,
                baseStyle: baseStyle,
                baseFontSize: baseFontSize,
                minFontSize: wrappedMinFontSize,
                maxLines: wrappedMaxLines,
              ) ??
              wrappedMinFontSize;
        }

        final textStyle = baseStyle.copyWith(fontSize: resolvedFontSize);
        final lineHeight = textStyle.height ?? 1.2;

        return SizedBox(
          height: resolvedHeight,
          child: Center(
            child: Align(
              alignment: textAlign == TextAlign.center ? Alignment.center : Alignment.centerLeft,
              child: Text(
                text,
                style: textStyle,
                textAlign: textAlign,
                maxLines: useWrappedLayout ? wrappedMaxLines : 1,
                overflow: TextOverflow.ellipsis,
                softWrap: useWrappedLayout,
                strutStyle: StrutStyle(
                  fontSize: resolvedFontSize,
                  height: lineHeight,
                  leading: 0,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _lineHeight(TextStyle style, double fontSize) {
    return fontSize * (style.height ?? 1.2);
  }

  double? _findLargestFittingFontSize({
    required String text,
    required double maxWidth,
    required TextDirection textDirection,
    required TextStyle baseStyle,
    required double baseFontSize,
    required double minFontSize,
    required int maxLines,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return baseFontSize;
    }

    for (double size = baseFontSize; size >= minFontSize; size -= 0.5) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: baseStyle.copyWith(fontSize: size)),
        textDirection: textDirection,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

      if (!painter.didExceedMaxLines) {
        return size;
      }
    }

    return null;
  }
}
