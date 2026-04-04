import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/theme_preferences_record.dart';
import 'package:hai_schedule/utils/app_storage_schema.dart';

class ThemePreferencesStore {
  const ThemePreferencesStore._();

  static Future<ThemePreferencesRecord> load() async {
    final prefs = await SharedPreferences.getInstance();
    var customBgPath = prefs.getString(AppStorageSchema.customBgPathKey);
    if (customBgPath != null && !File(customBgPath).existsSync()) {
      customBgPath = null;
    }

    return ThemePreferencesRecord(
      themeId:
          prefs.getString(AppStorageSchema.themeIdKey) ??
          ThemePreferencesRecord.defaultThemeId,
      systemLightThemeId:
          prefs.getString(AppStorageSchema.systemLightThemeIdKey) ??
          ThemePreferencesRecord.defaultSystemLightThemeId,
      systemDarkThemeId:
          prefs.getString(AppStorageSchema.systemDarkThemeIdKey) ??
          ThemePreferencesRecord.defaultSystemDarkThemeId,
      followSystemTheme:
          prefs.getBool(AppStorageSchema.followSystemThemeKey) ?? false,
      customBgPath: customBgPath,
      bgOpacity:
          prefs.getDouble(AppStorageSchema.bgOpacityKey) ??
          ThemePreferencesRecord.recommendedBgOpacity,
      bgBlur:
          prefs.getDouble(AppStorageSchema.bgBlurKey) ??
          ThemePreferencesRecord.recommendedBgBlur,
      cardOpacity:
          prefs.getDouble(AppStorageSchema.cardOpacityKey) ??
          ThemePreferencesRecord.recommendedCardOpacity,
    );
  }

  static Future<void> save(ThemePreferencesRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppStorageSchema.themeIdKey, record.themeId);
    await prefs.setString(
      AppStorageSchema.systemLightThemeIdKey,
      record.systemLightThemeId,
    );
    await prefs.setString(
      AppStorageSchema.systemDarkThemeIdKey,
      record.systemDarkThemeId,
    );
    await prefs.setBool(
      AppStorageSchema.followSystemThemeKey,
      record.followSystemTheme,
    );
    if (record.customBgPath != null) {
      await prefs.setString(
        AppStorageSchema.customBgPathKey,
        record.customBgPath!,
      );
    } else {
      await prefs.remove(AppStorageSchema.customBgPathKey);
    }
    await prefs.setDouble(AppStorageSchema.bgOpacityKey, record.bgOpacity);
    await prefs.setDouble(AppStorageSchema.bgBlurKey, record.bgBlur);
    await prefs.setDouble(AppStorageSchema.cardOpacityKey, record.cardOpacity);
  }
}
