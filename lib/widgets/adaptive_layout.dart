import 'package:flutter/material.dart';

class AdaptiveLayout {
  const AdaptiveLayout._();

  static const double tabletWidth = 600;
  static const double wideWidth = 960;
  static const double largeWidth = 1200;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletWidth;

  static bool isWide(BuildContext context, {double breakpoint = wideWidth}) =>
      MediaQuery.sizeOf(context).width >= breakpoint;

  static int columnsForWidth(
    double maxWidth, {
    double minTileWidth = 160,
    int minCount = 2,
    int maxCount = 6,
  }) {
    final computed = (maxWidth / minTileWidth).floor();
    return computed.clamp(minCount, maxCount);
  }
}

class AdaptivePage extends StatelessWidget {
  const AdaptivePage({
    super.key,
    required this.child,
    this.maxWidth = 1240,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 18),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class AdaptiveSheet extends StatelessWidget {
  const AdaptiveSheet({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
