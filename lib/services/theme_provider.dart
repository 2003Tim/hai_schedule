import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hai_schedule/models/app_theme_preset.dart';
import 'package:hai_schedule/models/theme_preferences_record.dart';
import 'package:hai_schedule/utils/app_logger.dart';
import 'package:hai_schedule/utils/theme_appearance.dart';
import 'package:hai_schedule/utils/theme_background_store.dart';
import 'package:hai_schedule/utils/theme_preferences_store.dart';
import 'package:hai_schedule/services/widget_sync_service.dart';

export '../models/app_theme_preset.dart';

class ThemeProvider extends ChangeNotifier {
  static const double recommendedBgOpacity =
      ThemePreferencesRecord.recommendedBgOpacity;
  static const double recommendedBgBlur =
      ThemePreferencesRecord.recommendedBgBlur;
  static const double recommendedCardOpacity =
      ThemePreferencesRecord.recommendedCardOpacity;

  ThemePreferencesRecord _record = const ThemePreferencesRecord();
  late final Future<void> ready = _loadPrefs();

  ThemeProvider();

  String get themeId => _record.themeId;
  String get systemLightThemeId => _record.systemLightThemeId;
  String get systemDarkThemeId => _record.systemDarkThemeId;
  bool get followSystemTheme => _record.followSystemTheme;
  String? get customBgPath => _record.customBgPath;
  double get bgOpacity => _record.bgOpacity;
  double get bgBlur => _record.bgBlur;
  double get cardOpacity => _record.cardOpacity;
  bool get hasCustomBg => _record.hasCustomBg;

  AppThemePreset get currentPreset => AppThemes.getById(_record.themeId);
  AppThemePreset get systemLightPreset =>
      AppThemes.getById(_record.systemLightThemeId);
  AppThemePreset get systemDarkPreset =>
      AppThemes.getById(_record.systemDarkThemeId);

  ThemeMode get themeMode {
    if (_record.followSystemTheme) return ThemeMode.system;
    return currentPreset.brightness == Brightness.dark
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  AppThemePreset presetForBrightness(Brightness brightness) {
    return ThemeAppearance.presetForBrightness(
      followSystemTheme: _record.followSystemTheme,
      currentPreset: currentPreset,
      systemLightPreset: systemLightPreset,
      systemDarkPreset: systemDarkPreset,
      brightness: brightness,
    );
  }

  Color glassPanelFill(Brightness brightness, {double strength = 1.0}) {
    return ThemeAppearance.glassPanelFill(
      presetForBrightness(brightness),
      hasCustomBg: hasCustomBg,
      strength: strength,
    );
  }

  Color glassPanelStrongFill(Brightness brightness, {double strength = 1.0}) {
    return ThemeAppearance.glassPanelStrongFill(
      presetForBrightness(brightness),
      hasCustomBg: hasCustomBg,
      strength: strength,
    );
  }

  Color glassOutline(Brightness brightness, {double strength = 1.0}) {
    return ThemeAppearance.glassOutline(
      presetForBrightness(brightness),
      strength: strength,
    );
  }

  Color glassHighlight(Brightness brightness, {double strength = 1.0}) {
    return ThemeAppearance.glassHighlight(
      presetForBrightness(brightness),
      strength: strength,
    );
  }

  ThemeData themeDataFor(Brightness brightness) {
    return ThemeAppearance.buildThemeData(
      presetForBrightness(brightness),
      hasCustomBg: hasCustomBg,
    );
  }

  ThemeData get themeData => themeDataFor(Brightness.light);
  ThemeData get darkThemeData => themeDataFor(Brightness.dark);

  void setTheme(String id) {
    _updateRecord(_record.copyWith(themeId: id), refreshWidget: true);
  }

  void setFollowSystemTheme(bool value) {
    _updateRecord(
      _record.copyWith(followSystemTheme: value),
      refreshWidget: true,
    );
  }

  void setSystemLightTheme(String id) {
    _updateRecord(
      _record.copyWith(systemLightThemeId: id),
      refreshWidget: true,
    );
  }

  void setSystemDarkTheme(String id) {
    _updateRecord(_record.copyWith(systemDarkThemeId: id), refreshWidget: true);
  }

  Future<void> setCustomBackground(String imagePath) async {
    final previousPath = _record.customBgPath;
    final copiedPath = await ThemeBackgroundStore.copyCustomBackground(
      imagePath,
    );

    _record = _record.copyWith(customBgPath: copiedPath);
    await ThemePreferencesStore.save(_record);
    await ThemeBackgroundStore.cleanupBackground(previousPath);
    notifyListeners();
  }

  Future<void> removeCustomBackground() async {
    final previousPath = _record.customBgPath;
    _record = _record.copyWith(clearCustomBg: true);
    await ThemePreferencesStore.save(_record);
    await ThemeBackgroundStore.cleanupBackground(previousPath);
    notifyListeners();
  }

  void applyRecommendedGlassTuning() {
    _updateRecord(
      _record.copyWith(
        bgOpacity: recommendedBgOpacity,
        bgBlur: recommendedBgBlur,
        cardOpacity: recommendedCardOpacity,
      ),
    );
  }

  void setBgOpacity(double value) {
    _updateRecord(_record.copyWith(bgOpacity: value.clamp(0.0, 1.0)));
  }

  void setBgBlur(double value) {
    _updateRecord(_record.copyWith(bgBlur: value.clamp(0.0, 30.0)));
  }

  void setCardOpacity(double value) {
    _updateRecord(_record.copyWith(cardOpacity: value.clamp(0.5, 1.0)));
  }

  Future<void> reloadFromStorage() => _loadPrefs();

  Future<void> _loadPrefs() async {
    _record = await ThemePreferencesStore.load();
    notifyListeners();
  }

  void _updateRecord(
    ThemePreferencesRecord nextRecord, {
    bool refreshWidget = false,
  }) {
    _record = nextRecord;
    unawaited(
      ThemePreferencesStore.save(_record).catchError(
        (Object e, StackTrace _) =>
            AppLogger.warn('ThemeProvider', '主题偏好保存失败', e),
      ),
    );
    if (refreshWidget) {
      _refreshWidgetAppearance();
    }
    notifyListeners();
  }

  void _refreshWidgetAppearance() {
    unawaited(
      WidgetSyncService.refreshWidget().catchError(
        (Object e, StackTrace _) =>
            AppLogger.warn('ThemeProvider', 'Widget 外观刷新失败', e),
      ),
    );
  }
}
