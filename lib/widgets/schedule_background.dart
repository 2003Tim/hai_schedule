import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

class ScheduleBackground extends StatelessWidget {
  final Widget child;
  final double? maxBlurSigma;

  const ScheduleBackground({super.key, required this.child, this.maxBlurSigma});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        final brightness = Theme.of(context).brightness;
        final preset = theme.presetForBrightness(brightness);
        final effectiveBlur =
            maxBlurSigma == null
                ? theme.bgBlur
                : (theme.bgBlur > maxBlurSigma! ? maxBlurSigma! : theme.bgBlur);
        if (!theme.hasCustomBg) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  preset.backgroundColor,
                  Color.alphaBlend(
                    preset.primaryColor.withValues(alpha: 0.05),
                    preset.backgroundColor,
                  ),
                ],
              ),
            ),
            child: child,
          );
        }

        final baseOverlay = theme.bgOpacity;
        final topOpacity =
            ((baseOverlay +
                            (preset.brightness == Brightness.dark
                                ? 0.18
                                : 0.22))
                        .clamp(0.0, 0.95)
                    as num)
                .toDouble();
        final middleOpacity =
            ((baseOverlay +
                            (preset.brightness == Brightness.dark
                                ? 0.12
                                : 0.16))
                        .clamp(0.0, 0.95)
                    as num)
                .toDouble();
        final bottomOpacity =
            ((baseOverlay +
                            (preset.brightness == Brightness.dark
                                ? 0.16
                                : 0.18))
                        .clamp(0.0, 0.95)
                    as num)
                .toDouble();

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              key: ValueKey(theme.customBgPath),
              File(theme.customBgPath!),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) {
                return Container(color: preset.backgroundColor);
              },
            ),
            if (effectiveBlur > 0)
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: effectiveBlur,
                    sigmaY: effectiveBlur,
                  ),
                  child: Container(color: Colors.transparent),
                ),
              ),
            Container(
              color: preset.backgroundColor.withValues(
                alpha:
                    ((baseOverlay + 0.04).clamp(0.0, 0.95) as num).toDouble(),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    preset.backgroundColor.withValues(alpha: topOpacity),
                    preset.backgroundColor.withValues(alpha: middleOpacity),
                    preset.backgroundColor.withValues(alpha: bottomOpacity),
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.20),
                  radius: 1.0,
                  colors: [
                    preset.primaryColor.withValues(
                      alpha: preset.brightness == Brightness.dark ? 0.06 : 0.08,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            child,
          ],
        );
      },
    );
  }
}
