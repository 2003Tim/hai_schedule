import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/theme_preferences_record.dart';

class ThemePreferencesStore {
  const ThemePreferencesStore._();

  static const String _prefsThemeId = 'theme_id';
  static const String _prefsBgPath = 'custom_bg_path';
  static const String _prefsBgOpacity = 'bg_opacity';
  static const String _prefsBgBlur = 'bg_blur';
  static const String _prefsCardOpacity = 'card_opacity';
  static const String _prefsFollowSystem = 'follow_system_theme';
  static const String _prefsSystemLightThemeId = 'system_light_theme_id';
  static const String _prefsSystemDarkThemeId = 'system_dark_theme_id';

  static Future<ThemePreferencesRecord> load() async {
    final prefs = await SharedPreferences.getInstance();
    var customBgPath = prefs.getString(_prefsBgPath);
    if (customBgPath != null && !File(customBgPath).existsSync()) {
      customBgPath = null;
    }

    return ThemePreferencesRecord(
      themeId:
          prefs.getString(_prefsThemeId) ??
          ThemePreferencesRecord.defaultThemeId,
      systemLightThemeId:
          prefs.getString(_prefsSystemLightThemeId) ??
          ThemePreferencesRecord.defaultSystemLightThemeId,
      systemDarkThemeId:
          prefs.getString(_prefsSystemDarkThemeId) ??
          ThemePreferencesRecord.defaultSystemDarkThemeId,
      followSystemTheme: prefs.getBool(_prefsFollowSystem) ?? false,
      customBgPath: customBgPath,
      bgOpacity:
          prefs.getDouble(_prefsBgOpacity) ??
          ThemePreferencesRecord.recommendedBgOpacity,
      bgBlur:
          prefs.getDouble(_prefsBgBlur) ??
          ThemePreferencesRecord.recommendedBgBlur,
      cardOpacity:
          prefs.getDouble(_prefsCardOpacity) ??
          ThemePreferencesRecord.recommendedCardOpacity,
    );
  }

  static Future<void> save(ThemePreferencesRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsThemeId, record.themeId);
    await prefs.setString(_prefsSystemLightThemeId, record.systemLightThemeId);
    await prefs.setString(_prefsSystemDarkThemeId, record.systemDarkThemeId);
    await prefs.setBool(_prefsFollowSystem, record.followSystemTheme);
    if (record.customBgPath != null) {
      await prefs.setString(_prefsBgPath, record.customBgPath!);
    } else {
      await prefs.remove(_prefsBgPath);
    }
    await prefs.setDouble(_prefsBgOpacity, record.bgOpacity);
    await prefs.setDouble(_prefsBgBlur, record.bgBlur);
    await prefs.setDouble(_prefsCardOpacity, record.cardOpacity);
  }
}
