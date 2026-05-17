import 'package:flutter/material.dart';

class AppLaunchSplashScreen extends StatelessWidget {
  static const String phoneAssetPath = 'images/HaiSchedule_splash_v3.png';
  static const String tabletAssetPath = 'images/HaiSchedule_splash_v3_pad.png';
  static const Color backgroundColor = Color(0xFFDDEAF7);
  static const Size _phoneDesignSize = Size(853, 1844);
  static const Size _tabletDesignSize = Size(1448, 1086);
  static const double _tabletBreakpoint = 600;

  static String assetPathForWidth(double width) {
    return width >= _tabletBreakpoint ? tabletAssetPath : phoneAssetPath;
  }

  static Size designSizeForWidth(double width) {
    return width >= _tabletBreakpoint ? _tabletDesignSize : _phoneDesignSize;
  }

  const AppLaunchSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final assetPath = assetPathForWidth(width);
    final designSize = designSizeForWidth(width);

    return ColoredBox(
      color: backgroundColor,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final scale = 0.985 + (0.015 * value);
          return Opacity(
            opacity: value,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: designSize.width,
              height: designSize.height,
              child: Image.asset(
                assetPath,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
