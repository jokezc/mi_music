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
  double _overflowDistance = 0;

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
      _controller.reset();
    }
  }

  void _syncAnimation(double overflowDistance) {
    if (overflowDistance <= 0) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      if (_overflowDistance != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _overflowDistance = 0);
          }
        });
      }
      return;
    }

    if ((_overflowDistance - overflowDistance).abs() > 0.5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _overflowDistance = overflowDistance);
      });
    }

    final milliseconds = (widget.speedPer100Px.inMilliseconds * (overflowDistance / 100)).round().clamp(1200, 12000);
    final nextDuration = Duration(milliseconds: milliseconds);

    if (_controller.duration != nextDuration) {
      _controller.duration = nextDuration;
      _controller.reset();
    }

    if (!_controller.isAnimating) {
      _loop();
    }
  }

  Future<void> _loop() async {
    while (mounted && _overflowDistance > 0) {
      await Future<void>.delayed(widget.pause);
      if (!mounted || _overflowDistance <= 0) break;
      await _controller.forward(from: 0);
      if (!mounted || _overflowDistance <= 0) break;
      await Future<void>.delayed(widget.pause);
      if (!mounted || _overflowDistance <= 0) break;
      _controller.reset();
    }
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
        final overflowDistance = textWidth > availableWidth ? textWidth - availableWidth : 0;

        _syncAnimation(overflowDistance);

        if (overflowDistance <= 0) {
          return Text(widget.text, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis);
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final dx = -_overflowDistance * Curves.easeInOut.transform(_controller.value);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(right: widget.gap),
                child: Text(
                  widget.text,
                  style: textStyle,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
