import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../models/storage_records.dart';
import '../utils/app_storage_codec.dart';

export '../models/storage_records.dart';

class AppStorage {
  AppStorage._();

  static final AppStorage instance = AppStorage._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String _coursesKey = 'courses';
  static const String _displayDaysKey = 'display_days';
  static const String _showNonCurrentWeekKey = 'show_non_current_week';

  static const String _lastFetchTimeKey = 'last_fetch_time';
  static const String _lastAttemptTimeKey = 'last_auto_sync_attempt_time';
  static const String _lastErrorKey = 'last_auto_sync_error';
  static const String _lastMessageKey = 'last_auto_sync_message';
  static const String _lastStateKey = 'last_auto_sync_state';
  static const String _lastSourceKey = 'last_auto_sync_source';
  static const String _lastDiffSummaryKey = 'last_auto_sync_diff_summary';
  static const String _nextSyncTimeKey = 'next_background_sync_time';
  static const String _frequencyKey = 'auto_sync_frequency';
  static const String _customIntervalMinutesKey =
      'auto_sync_custom_interval_minutes';
  static const String _semesterKey = 'last_semester_code';
  static const String _legacySemesterKey = 'current_semester';
  static const String _activeSemesterKey = 'active_semester_code';
  static const String _scheduleArchiveKey = 'schedule_archive_by_semester';
  static const String _scheduleOverridesKey = 'schedule_overrides';
  static const String _schoolTimeConfigKey = 'school_time_config';
  static const String _schoolTimeGeneratorSettingsKey =
      'school_time_generator_settings';
  static const String _lastScheduleJsonKey = 'last_schedule_json';
  static const String _cookieSnapshotKey = 'last_auto_sync_cookie';
  static const String _studentIdKey = 'last_student_id';
  static const String _reminderLeadTimeKey = 'class_reminder_lead_minutes';
  static const String _reminderLastBuildTimeKey =
      'class_reminder_last_build_time';
  static const String _reminderHorizonEndKey = 'class_reminder_horizon_end';
  static const String _reminderScheduledCountKey =
      'class_reminder_scheduled_count';
  static const String _reminderExactAlarmEnabledKey =
      'class_reminder_exact_alarm_enabled';

  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get _prefs =>
      _prefsFuture ??= SharedPreferences.getInstance();

  void resetForTesting() {
    _prefsFuture = null;
  }

  Future<List<Course>> loadCourses() async {
    final prefs = await _reloadedPrefs();
    final activeSemester = _readActiveSemesterCode(prefs);
    if (activeSemester != null && activeSemester.isNotEmpty) {
      final archive = AppStorageCodec.readSemesterArchive(
        await _loadScheduleArchiveMapFromPrefs(prefs),
        activeSemester,
      );
      return archive?.courses ?? const <Course>[];
    }

    return AppStorageCodec.decodeGlobalCourseMirror(
      prefs.getStringList(_coursesKey),
    );
  }

  Future<void> saveCourses(List<Course> courses) async {
    final prefs = await _prefs;
    final jsonList =
        courses.map((course) => json.encode(course.toJson())).toList();
    await prefs.setStringList(_coursesKey, jsonList);

    final activeSemester = await loadActiveSemesterCode();
    if (activeSemester != null && activeSemester.isNotEmpty) {
      await saveSemesterArchive(semesterCode: activeSemester, courses: courses);
    }
  }

  Future<String?> loadRawScheduleJson() async {
    final prefs = await _reloadedPrefs();
    final activeSemester = _readActiveSemesterCode(prefs);
    if (activeSemester != null && activeSemester.isNotEmpty) {
      final archive = AppStorageCodec.readSemesterArchive(
        await _loadScheduleArchiveMapFromPrefs(prefs),
        activeSemester,
      );
      return archive?.rawScheduleJson;
    }

    return prefs.getString(_lastScheduleJsonKey);
  }

  Future<void> saveRawScheduleJson(String jsonValue) async {
    final prefs = await _prefs;
    await prefs.setString(_lastScheduleJsonKey, jsonValue);

    final activeSemester = await loadActiveSemesterCode();
    if (activeSemester != null && activeSemester.isNotEmpty) {
      await saveSemesterArchive(
        semesterCode: activeSemester,
        rawScheduleJson: jsonValue,
      );
    }
  }

  Future<String?> loadSemesterCode() async {
    final prefs = await _reloadedPrefs();
    return _readSemesterCode(prefs);
  }

  Future<String?> loadActiveSemesterCode() async {
    final prefs = await _reloadedPrefs();
    return _readActiveSemesterCode(prefs);
  }

  Future<void> saveSemesterCode(String semester) async {
    final prefs = await _reloadedPrefs();
    await prefs.setString(_semesterKey, semester);
    await prefs.setString(_legacySemesterKey, semester);
    await prefs.setString(_activeSemesterKey, semester);
  }

  Future<void> saveActiveSemesterCode(String semester) async {
    final prefs = await _reloadedPrefs();
    final archive = await _loadScheduleArchiveMapFromPrefs(prefs);
    final entry =
        archive[semester] is Map<String, dynamic>
            ? Map<String, dynamic>.from(
              archive[semester] as Map<String, dynamic>,
            )
            : null;
    await _applyActiveSemesterSnapshot(
      prefs,
      semesterCode: semester,
      entry: entry,
    );
  }

  Future<List<String>> loadAvailableSemesterCodes() async {
    final prefs = await _reloadedPrefs();
    final archive = AppStorageCodec.decodeScheduleArchiveMap(
      prefs.getString(_scheduleArchiveKey),
    );
    final codes = archive.keys.toList()..sort((a, b) => b.compareTo(a));
    if (codes.isEmpty) {
      final legacy = _readSemesterCode(prefs);
      return legacy == null || legacy.isEmpty ? const [] : <String>[legacy];
    }
    return codes;
  }

  Future<StoredSemesterSchedule?> loadSemesterArchive(
    String semesterCode,
  ) async {
    final prefs = await _reloadedPrefs();
    return AppStorageCodec.readSemesterArchive(
      await _loadScheduleArchiveMapFromPrefs(prefs),
      semesterCode,
    );
  }

  Future<void> saveSemesterArchive({
    required String semesterCode,
    String? rawScheduleJson,
    List<Course>? courses,
    bool makeActive = false,
  }) async {
    final prefs = await _reloadedPrefs();
    final archive = await _loadScheduleArchiveMapFromPrefs(prefs);
    final previous = archive[semesterCode];
    final previousMap =
        previous is Map<String, dynamic>
            ? Map<String, dynamic>.from(previous)
            : <String, dynamic>{};

    if (rawScheduleJson != null) {
      previousMap['rawScheduleJson'] = rawScheduleJson;
    }
    if (courses != null) {
      previousMap['courses'] =
          courses.map((course) => course.toJson()).toList();
    }

    archive[semesterCode] = previousMap;

    await prefs.setString(
      _scheduleArchiveKey,
      AppStorageCodec.encodeScheduleArchiveMap(archive),
    );

    if (makeActive) {
      await _applyActiveSemesterSnapshot(
        prefs,
        semesterCode: semesterCode,
        entry: previousMap,
      );
    }
  }

  Future<void> deleteSemesterArchive(String semesterCode) async {
    final prefs = await _reloadedPrefs();
    final archive = await _loadScheduleArchiveMapFromPrefs(prefs);
    archive.remove(semesterCode);

    await prefs.setString(
      _scheduleArchiveKey,
      AppStorageCodec.encodeScheduleArchiveMap(archive),
    );

    final overrides = AppStorageCodec.decodeScheduleOverrides(
      prefs.getString(_scheduleOverridesKey),
    );
    final retainedOverrides =
        overrides.where((item) => item.semesterCode != semesterCode).toList();
    await prefs.setString(
      _scheduleOverridesKey,
      AppStorageCodec.encodeScheduleOverrides(retainedOverrides),
    );

    final activeSemester = _readActiveSemesterCode(prefs);
    final storedSemester = _readSemesterCode(prefs);
    final legacySemester = prefs.getString(_legacySemesterKey);
    if (activeSemester == semesterCode ||
        storedSemester == semesterCode ||
        legacySemester == semesterCode) {
      final fallbackCodes =
          archive.keys.toList()..sort((a, b) => b.compareTo(a));
      if (fallbackCodes.isNotEmpty) {
        final fallbackCode = fallbackCodes.first;
        final fallbackEntry =
            archive[fallbackCode] is Map<String, dynamic>
                ? Map<String, dynamic>.from(
                  archive[fallbackCode] as Map<String, dynamic>,
                )
                : null;
        await _applyActiveSemesterSnapshot(
          prefs,
          semesterCode: fallbackCode,
          entry: fallbackEntry,
        );
      } else {
        await _applyActiveSemesterSnapshot(prefs);
      }
    }
  }

  Future<List<ScheduleOverride>> loadScheduleOverrides({
    String? semesterCode,
  }) async {
    final prefs = await _reloadedPrefs();
    final allOverrides = AppStorageCodec.decodeScheduleOverrides(
      prefs.getString(_scheduleOverridesKey),
    );
    final activeSemester = semesterCode ?? _readActiveSemesterCode(prefs);
    return allOverrides
        .where(
          (item) =>
              activeSemester == null || item.semesterCode == activeSemester,
        )
        .toList();
  }

  Future<void> saveScheduleOverrides(
    List<ScheduleOverride> overrides, {
    required String semesterCode,
  }) async {
    final prefs = await _reloadedPrefs();
    final existing = AppStorageCodec.decodeScheduleOverrides(
      prefs.getString(_scheduleOverridesKey),
    );

    final merged =
        existing.where((item) => item.semesterCode != semesterCode).toList()
          ..addAll(overrides);

    await prefs.setString(
      _scheduleOverridesKey,
      AppStorageCodec.encodeScheduleOverrides(merged),
    );
  }

  Future<SchoolTimeConfig> loadSchoolTimeConfig() async {
    final prefs = await _prefs;
    return AppStorageCodec.decodeSchoolTimeConfig(
      prefs.getString(_schoolTimeConfigKey),
    );
  }

  Future<void> saveSchoolTimeConfig(SchoolTimeConfig config) async {
    final prefs = await _prefs;
    await prefs.setString(_schoolTimeConfigKey, json.encode(config.toJson()));
  }

  Future<void> clearSchoolTimeConfig() async {
    final prefs = await _prefs;
    await prefs.remove(_schoolTimeConfigKey);
    await prefs.remove(_schoolTimeGeneratorSettingsKey);
  }

  Future<SchoolTimeGeneratorSettings> loadSchoolTimeGeneratorSettings() async {
    final prefs = await _prefs;
    return AppStorageCodec.decodeSchoolTimeGeneratorSettings(
      prefs.getString(_schoolTimeGeneratorSettingsKey),
    );
  }

  Future<void> saveSchoolTimeGeneratorSettings(
    SchoolTimeGeneratorSettings settings,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      _schoolTimeGeneratorSettingsKey,
      json.encode(settings.toJson()),
    );
  }

  Future<ScheduleViewPreferences> loadScheduleViewPreferences() async {
    final prefs = await _prefs;
    return ScheduleViewPreferences(
      displayDays: prefs.getInt(_displayDaysKey) ?? 7,
      showNonCurrentWeek: prefs.getBool(_showNonCurrentWeekKey) ?? true,
    );
  }

  Future<void> saveScheduleViewPreferences({
    required int displayDays,
    required bool showNonCurrentWeek,
  }) async {
    final prefs = await _prefs;
    await prefs.setInt(_displayDaysKey, displayDays);
    await prefs.setBool(_showNonCurrentWeekKey, showNonCurrentWeek);
  }

  Future<StoredAutoSyncRecord> loadAutoSyncRecord() async {
    final prefs = await _prefs;
    await prefs.reload();
    return StoredAutoSyncRecord(
      frequency: prefs.getString(_frequencyKey) ?? 'daily',
      customIntervalMinutes: prefs.getInt(_customIntervalMinutesKey),
      lastFetchTime: AppStorageCodec.readTime(
        prefs.getString(_lastFetchTimeKey),
      ),
      lastAttemptTime: AppStorageCodec.readTime(
        prefs.getString(_lastAttemptTimeKey),
      ),
      nextSyncTime: AppStorageCodec.readTime(prefs.getString(_nextSyncTimeKey)),
      state: prefs.getString(_lastStateKey),
      message: prefs.getString(_lastMessageKey),
      lastError: prefs.getString(_lastErrorKey),
      lastSource: prefs.getString(_lastSourceKey),
      lastDiffSummary: prefs.getString(_lastDiffSummaryKey),
      semesterCode:
          prefs.getString(_activeSemesterKey) ??
          prefs.getString(_semesterKey) ??
          prefs.getString(_legacySemesterKey),
      cookieSnapshot: await loadCookieSnapshot(),
      rawScheduleJson: prefs.getString(_lastScheduleJsonKey),
    );
  }

  Future<void> saveAutoSyncSettings(
    String frequency, {
    int? customIntervalMinutes,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_frequencyKey, frequency);
    if (customIntervalMinutes != null) {
      await prefs.setInt(_customIntervalMinutesKey, customIntervalMinutes);
    } else if (frequency != 'custom') {
      await prefs.remove(_customIntervalMinutesKey);
    }
  }

  Future<void> saveAutoSyncRecord({
    String? state,
    String? message,
    String? source,
    String? diffSummary,
    String? error,
    bool clearError = false,
    bool clearDiffSummary = false,
    DateTime? lastFetchTime,
    DateTime? lastAttemptTime,
    DateTime? nextSyncTime,
    bool clearNextSyncTime = false,
    String? cookieSnapshot,
  }) async {
    final prefs = await _prefs;

    if (state != null) {
      await prefs.setString(_lastStateKey, state);
    }
    if (message != null) {
      await prefs.setString(_lastMessageKey, message);
    }
    if (source != null) {
      await prefs.setString(_lastSourceKey, source);
    }
    if (diffSummary != null) {
      await prefs.setString(_lastDiffSummaryKey, diffSummary);
    } else if (clearDiffSummary) {
      await prefs.remove(_lastDiffSummaryKey);
    }
    if (error != null) {
      await prefs.setString(_lastErrorKey, error);
    } else if (clearError) {
      await prefs.remove(_lastErrorKey);
    }
    if (lastFetchTime != null) {
      await prefs.setString(_lastFetchTimeKey, lastFetchTime.toIso8601String());
    }
    if (lastAttemptTime != null) {
      await prefs.setString(
        _lastAttemptTimeKey,
        lastAttemptTime.toIso8601String(),
      );
    }
    if (nextSyncTime != null) {
      await prefs.setString(_nextSyncTimeKey, nextSyncTime.toIso8601String());
    } else if (clearNextSyncTime) {
      await prefs.remove(_nextSyncTimeKey);
    }
    if (cookieSnapshot != null) {
      await _secureStorage.write(
        key: _cookieSnapshotKey,
        value: cookieSnapshot,
      );
      await prefs.remove(_cookieSnapshotKey);
    }
  }

  Future<void> saveLastFetchTime(DateTime time) async {
    final prefs = await _prefs;
    await prefs.setString(_lastFetchTimeKey, time.toIso8601String());
  }

  Future<void> saveCookieSnapshot(String cookie) async {
    await _secureStorage.write(key: _cookieSnapshotKey, value: cookie);
    // 清理旧版本保存在 SharedPreferences 里的明文副本。
    final prefs = await _prefs;
    await prefs.remove(_cookieSnapshotKey);
  }

  Future<String?> loadCookieSnapshot() async {
    final secure = await _secureStorage.read(key: _cookieSnapshotKey);
    if (secure != null && secure.isNotEmpty) return secure;

    // 从旧版 SharedPreferences 明文存储迁移。
    final prefs = await _prefs;
    final legacy = prefs.getString(_cookieSnapshotKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _secureStorage.write(key: _cookieSnapshotKey, value: legacy);
      await prefs.remove(_cookieSnapshotKey);
      return legacy;
    }
    return null;
  }

  Future<void> clearCookieSnapshot() async {
    await _secureStorage.delete(key: _cookieSnapshotKey);
    final prefs = await _prefs;
    await prefs.remove(_cookieSnapshotKey);
  }

  Future<void> saveStudentId(String studentId) async {
    final prefs = await _prefs;
    await prefs.setString(_studentIdKey, studentId);
  }

  Future<String?> loadStudentId() async {
    final prefs = await _prefs;
    return prefs.getString(_studentIdKey);
  }

  Future<StoredReminderRecord> loadReminderRecord() async {
    final prefs = await _prefs;
    return StoredReminderRecord(
      leadMinutes: prefs.getInt(_reminderLeadTimeKey) ?? 0,
      lastBuildTime: AppStorageCodec.readTime(
        prefs.getString(_reminderLastBuildTimeKey),
      ),
      horizonEnd: AppStorageCodec.readTime(
        prefs.getString(_reminderHorizonEndKey),
      ),
      scheduledCount: prefs.getInt(_reminderScheduledCountKey) ?? 0,
      exactAlarmEnabled: prefs.getBool(_reminderExactAlarmEnabledKey) ?? false,
    );
  }

  Future<void> saveReminderLeadMinutes(int leadMinutes) async {
    final prefs = await _prefs;
    await prefs.setInt(_reminderLeadTimeKey, leadMinutes);
  }

  Future<void> saveReminderRecord({
    int? scheduledCount,
    DateTime? lastBuildTime,
    bool clearLastBuildTime = false,
    DateTime? horizonEnd,
    bool? exactAlarmEnabled,
    bool clearHorizonEnd = false,
  }) async {
    final prefs = await _prefs;
    if (scheduledCount != null) {
      await prefs.setInt(_reminderScheduledCountKey, scheduledCount);
    }
    if (lastBuildTime != null) {
      await prefs.setString(
        _reminderLastBuildTimeKey,
        lastBuildTime.toIso8601String(),
      );
    } else if (clearLastBuildTime) {
      await prefs.remove(_reminderLastBuildTimeKey);
    }
    if (horizonEnd != null) {
      await prefs.setString(
        _reminderHorizonEndKey,
        horizonEnd.toIso8601String(),
      );
    } else if (clearHorizonEnd) {
      await prefs.remove(_reminderHorizonEndKey);
    }
    if (exactAlarmEnabled != null) {
      await prefs.setBool(_reminderExactAlarmEnabledKey, exactAlarmEnabled);
    }
  }

  Future<SharedPreferences> _reloadedPrefs() async {
    final prefs = await _prefs;
    await prefs.reload();
    return prefs;
  }

  String? _readSemesterCode(SharedPreferences prefs) {
    return prefs.getString(_semesterKey) ?? prefs.getString(_legacySemesterKey);
  }

  String? _readActiveSemesterCode(SharedPreferences prefs) {
    return prefs.getString(_activeSemesterKey) ?? _readSemesterCode(prefs);
  }

  Future<void> _applyActiveSemesterSnapshot(
    SharedPreferences prefs, {
    String? semesterCode,
    Map<String, dynamic>? entry,
  }) async {
    if (semesterCode == null || semesterCode.isEmpty) {
      await prefs.remove(_activeSemesterKey);
      await prefs.remove(_semesterKey);
      await prefs.remove(_legacySemesterKey);
      await prefs.remove(_lastScheduleJsonKey);
      await prefs.remove(_coursesKey);
      return;
    }

    await prefs.setString(_activeSemesterKey, semesterCode);
    await prefs.setString(_semesterKey, semesterCode);
    await prefs.setString(_legacySemesterKey, semesterCode);

    final rawScheduleJson = entry?['rawScheduleJson'] as String?;
    if (rawScheduleJson != null && rawScheduleJson.isNotEmpty) {
      await prefs.setString(_lastScheduleJsonKey, rawScheduleJson);
    } else {
      await prefs.remove(_lastScheduleJsonKey);
    }

    final mirroredCourses = AppStorageCodec.encodeMirroredCourses(entry);
    if (mirroredCourses != null) {
      await prefs.setStringList(_coursesKey, mirroredCourses);
    } else {
      await prefs.remove(_coursesKey);
    }
  }

  Future<Map<String, dynamic>> _loadScheduleArchiveMapFromPrefs(
    SharedPreferences prefs,
  ) async {
    return AppStorageCodec.decodeScheduleArchiveMap(
      prefs.getString(_scheduleArchiveKey),
    );
  }
}
