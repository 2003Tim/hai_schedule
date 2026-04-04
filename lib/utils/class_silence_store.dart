import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/utils/app_storage_schema.dart';

class ClassSilenceStoredState {
  final bool enabled;
  final DateTime? lastBuildTime;
  final DateTime? horizonEnd;
  final int scheduledCount;

  const ClassSilenceStoredState({
    required this.enabled,
    this.lastBuildTime,
    this.horizonEnd,
    required this.scheduledCount,
  });
}

class ClassSilenceStore {
  const ClassSilenceStore._();

  static Future<ClassSilenceStoredState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ClassSilenceStoredState(
      enabled: prefs.getBool(AppStorageSchema.classSilenceEnabledKey) ?? false,
      lastBuildTime: _parseTime(
        prefs.getString(AppStorageSchema.classSilenceLastBuildTimeKey),
      ),
      horizonEnd: _parseTime(
        prefs.getString(AppStorageSchema.classSilenceHorizonEndKey),
      ),
      scheduledCount:
          prefs.getInt(AppStorageSchema.classSilenceScheduledCountKey) ?? 0,
    );
  }

  static Future<void> saveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppStorageSchema.classSilenceEnabledKey, enabled);
  }

  static Future<void> saveScheduleState({
    int? scheduledCount,
    DateTime? lastBuildTime,
    bool clearLastBuildTime = false,
    DateTime? horizonEnd,
    bool clearHorizonEnd = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (scheduledCount != null) {
      await prefs.setInt(
        AppStorageSchema.classSilenceScheduledCountKey,
        scheduledCount,
      );
    }
    if (lastBuildTime != null) {
      await prefs.setString(
        AppStorageSchema.classSilenceLastBuildTimeKey,
        lastBuildTime.toIso8601String(),
      );
    } else if (clearLastBuildTime) {
      await prefs.remove(AppStorageSchema.classSilenceLastBuildTimeKey);
    }
    if (horizonEnd != null) {
      await prefs.setString(
        AppStorageSchema.classSilenceHorizonEndKey,
        horizonEnd.toIso8601String(),
      );
    } else if (clearHorizonEnd) {
      await prefs.remove(AppStorageSchema.classSilenceHorizonEndKey);
    }
  }

  static DateTime? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }
}
