import 'package:flutter/material.dart';

/// 仅在文本宽度超出可用空间时自动横向滚动。
class OverflowMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double gap;
  final Duration pause;
  final Duration speedPer100Px;

  const OverflowMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.gap = 32,
    this.pause = const Duration(milliseconds: 900),
    this.speedPer100Px = const Duration(milliseconds: 2200),
  });

  @override
  State<OverflowMarqueeText> createState() => _OverflowMarqueeTextState();
}

class _OverflowMarqueeTextState extends State<OverflowMarqueeText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _animationToken = 0;
  double _cycleDistance = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OverflowMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _cycleDistance = 0;
      _animationToken++;
      _controller.reset();
    }
  }

  void _syncAnimation({
    required double overflowDistance,
    required double textWidth,
  }) {
    if (overflowDistance <= 0) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _cycleDistance = 0;
      _animationToken++;
      return;
    }

    final nextScrollDistance = textWidth + widget.gap;
    _cycleDistance = nextScrollDistance.ceilToDouble();

    final milliseconds =
        (widget.speedPer100Px.inMilliseconds * (nextScrollDistance / 100)).round().clamp(1200, 12000).toInt();
    final nextDuration = Duration(milliseconds: milliseconds);

    if (_controller.duration != nextDuration) {
      _controller.duration = nextDuration;
      _controller.reset();
      _animationToken++;
    }

    if (!_controller.isAnimating) {
      _startLoop();
    }
  }

  Future<void> _startLoop() async {
    final token = ++_animationToken;
    await Future<void>.delayed(widget.pause);
    if (!mounted || _cycleDistance <= 0 || token != _animationToken) return;
    if (_controller.duration == null) return;
    _controller.repeat(period: _controller.duration);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final defaultStyle = DefaultTextStyle.of(context).style;
        final textStyle = widget.style ?? defaultStyle;
        final textDirection = Directionality.of(context);

        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: textStyle),
          maxLines: 1,
          textDirection: textDirection,
        )..layout(maxWidth: double.infinity);

        final textWidth = painter.width;
        final availableWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : textWidth;
        final overflowDistance = textWidth > availableWidth ? textWidth - availableWidth : 0.0;

        _syncAnimation(
          overflowDistance: overflowDistance,
          textWidth: textWidth,
        );

        if (overflowDistance <= 0) {
          return SizedBox(
            width: availableWidth,
            child: Text(widget.text, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }

        return SizedBox(
          width: availableWidth,
          child: ClipRect(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
                  final rawDx = -_cycleDistance * _controller.value;
                  final snappedDx = (rawDx * devicePixelRatio).roundToDouble() / devicePixelRatio;
                  return Transform.translate(offset: Offset(snappedDx, 0), child: child);
                },
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.text,
                        style: textStyle,
                        maxLines: 1,
                        softWrap: false,
                      ),
                      SizedBox(width: widget.gap),
                      Text(
                        widget.text,
                        style: textStyle,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
