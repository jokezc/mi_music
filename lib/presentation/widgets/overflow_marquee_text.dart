import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 仅在文本超出可用空间时自动横向无缝滚动。
class OverflowMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double gap;
  final Duration speedPer100Px;
  final TextAlign textAlign;

  const OverflowMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.gap = 20,
    this.speedPer100Px = const Duration(milliseconds: 3200),
    this.textAlign = TextAlign.center,
  });

  @override
  State<OverflowMarqueeText> createState() => _OverflowMarqueeTextState();
}

class _OverflowMarqueeTextState extends State<OverflowMarqueeText>
    with TickerProviderStateMixin {
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  double _offset = 0;
  double _cycleWidth = 0;
  double _speed = 0;

  @override
  void didUpdateWidget(covariant OverflowMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _killTicker();
    }
  }

  @override
  void dispose() {
    _killTicker();
    super.dispose();
  }

  void _killTicker() {
    _ticker?.dispose();
    _ticker = null;
    _offset = 0;
    _cycleWidth = 0;
    _lastElapsed = Duration.zero;
  }

  void _ensureTicker(double textWidth) {
    _cycleWidth = textWidth + widget.gap;
    _speed = 100.0 / (widget.speedPer100Px.inMilliseconds / 1000.0);
    if (_ticker != null) return;
    _lastElapsed = Duration.zero;
    _offset = 0;
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    // 页面切换时 dt 会异常大，限制上限防止跳跃
    final dt =
        ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 1.0 / 15);
    _lastElapsed = elapsed;
    if (dt <= 0 || _cycleWidth <= 0) return;

    _offset = (_offset + _speed * dt) % _cycleWidth;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = widget.style ?? DefaultTextStyle.of(context).style;
        final textDir = Directionality.of(context);

        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          maxLines: 1,
          textDirection: textDir,
        )..layout(maxWidth: double.infinity);

        final textWidth = painter.width;
        final available =
            constraints.maxWidth.isFinite ? constraints.maxWidth : textWidth;

        if (textWidth <= available + 0.5) {
          if (_ticker != null) _killTicker();
          return SizedBox(
            width: available,
            child: Align(
              alignment: Alignment.center,
              child: Text(
                widget.text,
                style: textStyle,
                textAlign: widget.textAlign,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        }

        _ensureTicker(textWidth);

        return SizedBox(
          width: available,
          height: painter.height,
          child: CustomPaint(
            painter: _MarqueePainter(
              text: widget.text,
              style: textStyle,
              textDirection: textDir,
              textWidth: textWidth,
              gap: widget.gap,
              offset: _offset,
            ),
          ),
        );
      },
    );
  }
}

class _MarqueePainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final ui.TextDirection textDirection;
  final double textWidth;
  final double gap;
  final double offset;

  _MarqueePainter({
    required this.text,
    required this.style,
    required this.textDirection,
    required this.textWidth,
    required this.gap,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: textDirection,
    )..layout();

    final y = (size.height - tp.height) / 2;
    final cycleWidth = textWidth + gap;

    tp.paint(canvas, Offset(-offset, y));
    tp.paint(canvas, Offset(cycleWidth - offset, y));
  }

  @override
  bool shouldRepaint(_MarqueePainter old) =>
      old.offset != offset || old.text != text || old.style != style;
}
