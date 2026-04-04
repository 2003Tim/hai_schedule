import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/window_shell_preferences.dart';
import 'package:hai_schedule/utils/app_storage_schema.dart';

class WindowShellPreferencesStore {
  const WindowShellPreferencesStore._();

  static Future<WindowShellPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WindowShellPreferences(
      opacity: prefs.getDouble(AppStorageSchema.miniOpacityKey) ?? 0.95,
      alwaysOnTop:
          prefs.getBool(AppStorageSchema.miniAlwaysOnTopKey) ?? true,
    );
  }

  static Future<void> save(WindowShellPreferences record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppStorageSchema.miniOpacityKey, record.opacity);
    await prefs.setBool(
      AppStorageSchema.miniAlwaysOnTopKey,
      record.alwaysOnTop,
    );
  }
}
