import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/app_theme_preset.dart';
import 'package:hai_schedule/utils/theme_appearance.dart';

void main() {
  test('ThemeAppearance resolves system preset by brightness', () {
    final preset = ThemeAppearance.presetForBrightness(
      followSystemTheme: true,
      currentPreset: AppThemes.getById('blue'),
      systemLightPreset: AppThemes.getById('pink'),
      systemDarkPreset: AppThemes.getById('dark'),
      brightness: Brightness.dark,
    );

    expect(preset.id, 'dark');
  });

  test('ThemeAppearance builds theme data with matching brightness', () {
    final themeData = ThemeAppearance.buildThemeData(
      AppThemes.getById('purple'),
      hasCustomBg: true,
    );

    expect(themeData.brightness, Brightness.dark);
    expect(themeData.scaffoldBackgroundColor, const Color(0xFF1E1B2E));
  });

  test(
    'ThemeAppearance glass fills differ when custom background is enabled',
    () {
      final preset = AppThemes.getById('blue');

      final plain = ThemeAppearance.glassPanelFill(preset, hasCustomBg: false);
      final tinted = ThemeAppearance.glassPanelFill(preset, hasCustomBg: true);

      expect(tinted, isNot(equals(plain)));
    },
  );
}
