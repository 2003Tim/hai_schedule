import 'package:flutter/material.dart';

class AppLaunchSplashScreen extends StatelessWidget {
  static const String assetPath = 'HaiSchedule_splash_v3.png';
  static const Color backgroundColor = Color(0xFFDDEAF7);
  static const double _designWidth = 1080;
  static const double _designHeight = 1920;

  const AppLaunchSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: _designWidth,
                  height: _designHeight,
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
