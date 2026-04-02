import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/theme_preferences_record.dart';
import 'package:hai_schedule/utils/theme_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemePreferencesStore loads defaults when prefs are empty', () async {
    SharedPreferences.setMockInitialValues({});

    final record = await ThemePreferencesStore.load();

    expect(record.themeId, ThemePreferencesRecord.defaultThemeId);
    expect(
      record.systemLightThemeId,
      ThemePreferencesRecord.defaultSystemLightThemeId,
    );
    expect(
      record.systemDarkThemeId,
      ThemePreferencesRecord.defaultSystemDarkThemeId,
    );
    expect(record.followSystemTheme, isFalse);
    expect(record.customBgPath, isNull);
    expect(record.bgOpacity, ThemePreferencesRecord.recommendedBgOpacity);
    expect(record.bgBlur, ThemePreferencesRecord.recommendedBgBlur);
    expect(record.cardOpacity, ThemePreferencesRecord.recommendedCardOpacity);
  });

  test('ThemePreferencesStore saves and reloads a complete record', () async {
    final tempDir = await Directory.systemTemp.createTemp('hai_schedule_theme');
    final imageFile = File('${tempDir.path}/wallpaper.png')
      ..writeAsStringSync('x');
    SharedPreferences.setMockInitialValues({});

    const initial = ThemePreferencesRecord(
      themeId: 'green',
      systemLightThemeId: 'pink',
      systemDarkThemeId: 'purple',
      followSystemTheme: true,
      bgOpacity: 0.4,
      bgBlur: 12,
      cardOpacity: 0.88,
    );

    await ThemePreferencesStore.save(
      initial.copyWith(customBgPath: imageFile.path),
    );
    final record = await ThemePreferencesStore.load();

    expect(record.themeId, 'green');
    expect(record.systemLightThemeId, 'pink');
    expect(record.systemDarkThemeId, 'purple');
    expect(record.followSystemTheme, isTrue);
    expect(record.customBgPath, imageFile.path);
    expect(record.bgOpacity, 0.4);
    expect(record.bgBlur, 12);
    expect(record.cardOpacity, 0.88);

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });
}
