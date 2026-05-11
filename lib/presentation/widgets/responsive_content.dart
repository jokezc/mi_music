import 'package:flutter/material.dart';
import 'package:mi_music/core/constants/breakpoints.dart';

/// 为页面主体提供统一的宽屏约束和自适应留白。
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Alignment alignment;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= Breakpoints.navRail;
        final horizontalPadding = isWide ? 24.0 : 16.0;

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding.resolve(Directionality.of(context)).add(
                EdgeInsets.symmetric(horizontal: horizontalPadding - 16),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
