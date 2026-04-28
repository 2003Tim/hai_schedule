import 'dart:ui';

import 'package:flutter/material.dart';

class ScheduleUiTokens {
  const ScheduleUiTokens._();

  static const Color backgroundTop = Color(0xFFEEF0FF);
  static const Color backgroundBottom = Color(0xFFF5F7FF);
  static const Color backgroundGlow = Color(0xFFDCE4FF);
  static const Color accentBlue = Color(0xFF4A6CF7);
  static const Color primaryText = Color(0xFF1A1D2E);
  static const Color secondaryText = Color(0xFF8A8FA8);
  static const Color terracotta = Color(0xFFC46A49);
  static const Color warmCardTop = Color(0xFFFFF0E8);
  static const Color warmCardBottom = Color(0xFFFFE4CC);
  static const Color danger = Color(0xFFE05555);

  static const List<BoxShadow> softShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0F000000), blurRadius: 20, offset: Offset(0, 4)),
  ];

  static BorderRadius get cardRadius => BorderRadius.circular(16);
  static BorderRadius get sheetRadius => BorderRadius.circular(24);
  static BorderRadius get pillRadius => BorderRadius.circular(999);
  static BorderRadius get adaptiveGlassRadius => BorderRadius.circular(18);

  static ImageFilter get adaptiveGlassBlur {
    return ImageFilter.blur(sigmaX: 18, sigmaY: 18);
  }

  static LinearGradient get backgroundGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[backgroundTop, backgroundBottom],
  );

  static LinearGradient get warmBannerGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[warmCardTop, warmCardBottom],
  );

  static Color primaryTextFor(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.onSurface;
    }
    return primaryText;
  }

  static Color secondaryTextFor(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.70);
    }
    return secondaryText;
  }

  static Color glassBorderFor(ThemeData theme) {
    if (theme.brightness == Brightness.dark) {
      return Colors.white.withValues(alpha: 0.10);
    }
    return Colors.white.withValues(alpha: 0.60);
  }

  static Color glassFillFor(ThemeData theme, {double alpha = 0.72}) {
    if (theme.brightness == Brightness.dark) {
      return theme.colorScheme.surface.withValues(alpha: 0.82);
    }
    return Colors.white.withValues(alpha: alpha);
  }

  static BoxDecoration glassCardDecoration(
    ThemeData theme, {
    BorderRadius? borderRadius,
    Color? fillColor,
    Gradient? gradient,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: gradient == null ? (fillColor ?? glassFillFor(theme)) : null,
      gradient: gradient,
      borderRadius: borderRadius ?? cardRadius,
      border: Border.all(color: borderColor ?? glassBorderFor(theme), width: 1),
      boxShadow: softShadow,
    );
  }

  static Color adaptiveGlassTextFor(ThemeData theme) {
    final alpha = theme.brightness == Brightness.dark ? 0.72 : 0.56;
    return (theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface)
        .withValues(alpha: alpha);
  }

  static Color adaptiveGlassMetadataTextFor(ThemeData theme) {
    final alpha = theme.brightness == Brightness.dark ? 0.64 : 0.52;
    return theme.colorScheme.onSurface.withValues(alpha: alpha);
  }

  static double adaptiveGlassBorderWidthFor(ThemeData theme) {
    return theme.brightness == Brightness.dark ? 0.7 : 0.8;
  }

  static BoxDecoration adaptiveGlassDecoration(
    ThemeData theme, {
    BorderRadius? borderRadius,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return BoxDecoration(
      color:
          isDark
              ? theme.colorScheme.surface.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.34),
      borderRadius: borderRadius ?? adaptiveGlassRadius,
      border: Border.all(
        color:
            isDark
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.46),
        width: adaptiveGlassBorderWidthFor(theme),
      ),
    );
  }

  static BoxDecoration adaptiveGlassStateDecoration(
    ThemeData theme, {
    required bool selected,
    bool current = false,
    BorderRadius? borderRadius,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final baseColor =
        selected
            ? colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.14)
            : colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.08);
    return BoxDecoration(
      color: baseColor,
      borderRadius: borderRadius ?? pillRadius,
      border: Border.all(
        color: colorScheme.primary.withValues(
          alpha:
              selected
                  ? (isDark ? 0.34 : 0.22)
                  : current
                  ? 0.20
                  : 0.12,
        ),
        width: adaptiveGlassBorderWidthFor(theme),
      ),
    );
  }

  static bool isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class CoursePalette {
  const CoursePalette({
    required this.background,
    required this.foreground,
    Color? accent,
  }) : accent = accent ?? foreground;

  final Color background;
  final Color foreground;
  final Color accent;
}

class ScheduleCoursePalettes {
  const ScheduleCoursePalettes._();

  static const List<CoursePalette> _fallbackPalettes = <CoursePalette>[
    CoursePalette(background: Color(0xFFD3E8FB), foreground: Color(0xFF2F77B3)),
    CoursePalette(background: Color(0xFFFFE1D1), foreground: Color(0xFFC26026)),
    CoursePalette(background: Color(0xFFE7DEF6), foreground: Color(0xFF7553B2)),
    CoursePalette(background: Color(0xFFD8F0E3), foreground: Color(0xFF337B58)),
    CoursePalette(background: Color(0xFFFFE8BF), foreground: Color(0xFFB97A17)),
    CoursePalette(background: Color(0xFFFFD8E0), foreground: Color(0xFFBA4C77)),
    CoursePalette(background: Color(0xFFD7EEF0), foreground: Color(0xFF2B8090)),
    CoursePalette(background: Color(0xFFE2DCF8), foreground: Color(0xFF6450BA)),
  ];

  static CoursePalette resolve(String courseName) {
    final normalized = courseName.trim();
    switch (normalized) {
      case '数据挖掘':
        return const CoursePalette(
          background: Color(0xFFC8E6FA),
          foreground: Color(0xFF2D7FB8),
        );
      case '图像处理':
        return const CoursePalette(
          background: Color(0xFFFFD9C0),
          foreground: Color(0xFFB8541A),
        );
      case '计算机视觉':
        return const CoursePalette(
          background: Color(0xFFDDD4F0),
          foreground: Color(0xFF6B45B0),
        );
      case '机器学习':
        return const CoursePalette(
          background: Color(0xFFC8EED8),
          foreground: Color(0xFF2E7D52),
        );
    }

    var hash = 0x811c9dc5;
    for (final unit in normalized.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return _fallbackPalettes[hash % _fallbackPalettes.length];
  }

  static String shortCourseName(String courseName) {
    final trimmed = courseName.trim();
    if (trimmed.length <= 6) {
      return trimmed;
    }
    return '${trimmed.substring(0, 6)}…';
  }

  static String shortTeacher(String teacher) {
    final trimmed = teacher.trim();
    if (trimmed.contains(',')) {
      return trimmed.split(',').first.trim();
    }
    if (trimmed.contains('，')) {
      return trimmed.split('，').first.trim();
    }
    if (trimmed.length <= 8) {
      return trimmed;
    }
    return '${trimmed.substring(0, 8)}…';
  }
}
