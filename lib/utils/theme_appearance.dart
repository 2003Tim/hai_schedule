import 'package:flutter/material.dart';

import 'package:hai_schedule/models/app_theme_preset.dart';

class ThemeAppearance {
  const ThemeAppearance._();

  static AppThemePreset presetForBrightness({
    required bool followSystemTheme,
    required AppThemePreset currentPreset,
    required AppThemePreset systemLightPreset,
    required AppThemePreset systemDarkPreset,
    required Brightness brightness,
  }) {
    if (followSystemTheme) {
      return brightness == Brightness.dark
          ? systemDarkPreset
          : systemLightPreset;
    }
    return currentPreset;
  }

  static Color glassPanelFill(
    AppThemePreset preset, {
    required bool hasCustomBg,
    double strength = 1.0,
  }) {
    if (!hasCustomBg) {
      return Color.alphaBlend(
        preset.cardColor.withValues(
          alpha: preset.brightness == Brightness.dark ? 0.80 : 0.93,
        ),
        preset.backgroundColor,
      );
    }
    final base = _tintedGlassBase(preset);
    final baseOpacity = preset.brightness == Brightness.dark ? 0.26 : 0.30;
    return base.withValues(
      alpha: ((baseOpacity * strength).clamp(0.0, 0.95) as num).toDouble(),
    );
  }

  static Color glassPanelStrongFill(
    AppThemePreset preset, {
    required bool hasCustomBg,
    double strength = 1.0,
  }) {
    if (!hasCustomBg) {
      return Color.alphaBlend(
        preset.cardColor.withValues(
          alpha: preset.brightness == Brightness.dark ? 0.88 : 0.98,
        ),
        preset.backgroundColor,
      );
    }
    final base = Color.alphaBlend(
      preset.primaryColor.withValues(
        alpha: preset.brightness == Brightness.dark ? 0.22 : 0.14,
      ),
      _tintedGlassBase(preset),
    );
    final baseOpacity = preset.brightness == Brightness.dark ? 0.34 : 0.40;
    return base.withValues(
      alpha: ((baseOpacity * strength).clamp(0.0, 0.98) as num).toDouble(),
    );
  }

  static Color glassOutline(AppThemePreset preset, {double strength = 1.0}) {
    final opacity = preset.brightness == Brightness.dark ? 0.22 : 0.14;
    return preset.subtextColor.withValues(
      alpha: ((opacity * strength).clamp(0.0, 0.60) as num).toDouble(),
    );
  }

  static Color glassHighlight(AppThemePreset preset, {double strength = 1.0}) {
    final opacity = preset.brightness == Brightness.dark ? 0.10 : 0.20;
    return Colors.white.withValues(
      alpha: ((opacity * strength).clamp(0.0, 0.40) as num).toDouble(),
    );
  }

  static Color readableForeground(
    Color background, {
    Color light = Colors.white,
    Color dark = const Color(0xFF111111),
  }) {
    return background.computeLuminance() > 0.58 ? dark : light;
  }

  static ThemeData buildThemeData(
    AppThemePreset preset, {
    required bool hasCustomBg,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: preset.primaryColor,
      brightness: preset.brightness,
    );

    final surface =
        hasCustomBg
            ? glassPanelFill(preset, hasCustomBg: true, strength: 0.94)
            : Color.alphaBlend(
              preset.cardColor.withValues(
                alpha: preset.brightness == Brightness.dark ? 0.80 : 0.94,
              ),
              preset.backgroundColor,
            );

    final surfaceHigh =
        hasCustomBg
            ? glassPanelStrongFill(preset, hasCustomBg: true, strength: 0.94)
            : Color.alphaBlend(
              preset.cardColor.withValues(
                alpha: preset.brightness == Brightness.dark ? 0.88 : 0.98,
              ),
              preset.backgroundColor,
            );

    return ThemeData(
      useMaterial3: true,
      brightness: preset.brightness,
      colorScheme: scheme.copyWith(
        surface: surface,
        surfaceContainerHighest: surfaceHigh,
      ),
      scaffoldBackgroundColor: preset.backgroundColor,
      cardColor: preset.cardColor,
      dividerColor: preset.subtextColor.withValues(alpha: 0.12),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: preset.textColor),
        bodyMedium: TextStyle(color: preset.textColor),
        bodySmall: TextStyle(color: preset.subtextColor),
        titleLarge: TextStyle(
          color: preset.textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: preset.textColor,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );
  }

  static Color _tintedGlassBase(AppThemePreset preset) {
    final liftedCard = Color.alphaBlend(
      preset.backgroundColor.withValues(
        alpha: preset.brightness == Brightness.dark ? 0.10 : 0.06,
      ),
      preset.cardColor,
    );
    return Color.alphaBlend(
      preset.primaryColor.withValues(
        alpha: preset.brightness == Brightness.dark ? 0.14 : 0.09,
      ),
      liftedCard,
    );
  }
}
