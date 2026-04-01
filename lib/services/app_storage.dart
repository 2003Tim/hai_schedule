import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../utils/app_logger.dart';

class ScheduleViewPreferences {
  final int displayDays;
  final bool showNonCurrentWeek;

  const ScheduleViewPreferences({
    required this.displayDays,
    required this.showNonCurrentWeek,
  });
}

class StoredAutoSyncRecord {
  final String frequency;
  final int? customIntervalMinutes;
  final DateTime? lastFetchTime;
  final DateTime? lastAttemptTime;
  final DateTime? nextSyncTime;
  final String? state;
  final String? message;
  final String? lastError;
  final String? lastSource;
  final String? lastDiffSummary;
  final String? semesterCode;
  final String? cookieSnapshot;
  final String? rawScheduleJson;

  const StoredAutoSyncRecord({
    required this.frequency,
    this.customIntervalMinutes,
    this.lastFetchTime,
    this.lastAttemptTime,
    this.nextSyncTime,
    this.state,
    this.message,
    this.lastError,
    this.lastSource,
    this.lastDiffSummary,
    this.semesterCode,
    this.cookieSnapshot,
    this.rawScheduleJson,
  });

  bool get credentialReady =>
      (semesterCode?.isNotEmpty ?? false) &&
      (cookieSnapshot?.isNotEmpty ?? false);
}

class StoredReminderRecord {
  final int leadMinutes;
  final DateTime? lastBuildTime;
  final DateTime? horizonEnd;
  final int scheduledCount;
  final bool exactAlarmEnabled;

  const StoredReminderRecord({
    required this.leadMinutes,
    this.lastBuildTime,
    this.horizonEnd,
    required this.scheduledCount,
    required this.exactAlarmEnabled,
  });
}

class StoredSemesterSchedule {
  final List<Course> courses;
  final String? rawScheduleJson;
  final String semesterCode;

  const StoredSemesterSchedule({
    required this.courses,
    required this.semesterCode,
    this.rawScheduleJson,
  });
}

class StoredScheduleOverrideRecord {
  final List<ScheduleOverride> overrides;

  const StoredScheduleOverrideRecord({required this.overrides});
}

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
    final activeSemester = await loadActiveSemesterCode();
    if (activeSemester != null && activeSemester.isNotEmpty) {
      final archive = await loadSemesterArchive(activeSemester);
      if (archive != null && archive.courses.isNotEmpty) {
        return archive.courses;
      }
    }

    final prefs = await _prefs;
    final jsonList = prefs.getStringList(_coursesKey);
    if (jsonList == null || jsonList.isEmpty) {
      return const <Course>[];
    }

    return jsonList.map((s) {
      final data = json.decode(s) as Map<String, dynamic>;
      return Course.fromJson(data);
    }).toList();
  }

  Future<void> saveCourses(List<Course> courses) async {
    final prefs = await _prefs;
    final jsonList = courses.map((c) => json.encode(c.toJson())).toList();
    await prefs.setStringList(_coursesKey, jsonList);

    final activeSemester = await loadActiveSemesterCode();
    if (activeSemester != null && activeSemester.isNotEmpty) {
      await saveSemesterArchive(semesterCode: activeSemester, courses: courses);
    }
  }

  Future<String?> loadRawScheduleJson() async {
    final activeSemester = await loadActiveSemesterCode();
    if (activeSemester != null && activeSemester.isNotEmpty) {
      final archive = await loadSemesterArchive(activeSemester);
      if (archive?.rawScheduleJson?.isNotEmpty ?? false) {
        return archive!.rawScheduleJson;
      }
    }

    final prefs = await _prefs;
    return prefs.getString(_lastScheduleJsonKey);
  }

  Future<void> saveRawScheduleJson(String json) async {
    final prefs = await _prefs;
    await prefs.setString(_lastScheduleJsonKey, json);

    final activeSemester = await loadActiveSemesterCode();
    if (activeSemester != null && activeSemester.isNotEmpty) {
      await saveSemesterArchive(
        semesterCode: activeSemester,
        rawScheduleJson: json,
      );
    }
  }

  Future<String?> loadSemesterCode() async {
    final prefs = await _prefs;
    return prefs.getString(_semesterKey) ?? prefs.getString(_legacySemesterKey);
  }

  Future<String?> loadActiveSemesterCode() async {
    final prefs = await _prefs;
    return prefs.getString(_activeSemesterKey) ??
        prefs.getString(_semesterKey) ??
        prefs.getString(_legacySemesterKey);
  }

  Future<void> saveSemesterCode(String semester) async {
    final prefs = await _prefs;
    await prefs.setString(_semesterKey, semester);
    await prefs.setString(_legacySemesterKey, semester);
    await prefs.setString(_activeSemesterKey, semester);
  }

  Future<void> saveActiveSemesterCode(String semester) async {
    final prefs = await _prefs;
    await prefs.setString(_activeSemesterKey, semester);
  }

  Future<List<String>> loadAvailableSemesterCodes() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_scheduleArchiveKey);
    if (raw == null || raw.isEmpty) {
      final legacy = await loadSemesterCode();
      return legacy == null || legacy.isEmpty ? const [] : <String>[legacy];
    }

    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      return const [];
    }

    final codes = decoded.keys.toList()..sort((a, b) => b.compareTo(a));
    final legacy = await loadSemesterCode();
    if (legacy != null && legacy.isNotEmpty && !codes.contains(legacy)) {
      codes.insert(0, legacy);
    }
    return codes;
  }

  Future<StoredSemesterSchedule?> loadSemesterArchive(
    String semesterCode,
  ) async {
    final archive = await _loadScheduleArchiveMap();
    final raw = archive[semesterCode];
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    final rawScheduleJson = raw['rawScheduleJson'] as String?;
    final coursesJson = raw['courses'];
    final courses =
        coursesJson is List
            ? coursesJson
                .whereType<Map>()
                .map((item) => Course.fromJson(Map<String, dynamic>.from(item)))
                .toList()
            : const <Course>[];

    return StoredSemesterSchedule(
      courses: courses,
      rawScheduleJson: rawScheduleJson,
      semesterCode: semesterCode,
    );
  }

  Future<void> saveSemesterArchive({
    required String semesterCode,
    String? rawScheduleJson,
    List<Course>? courses,
    bool makeActive = false,
  }) async {
    final archive = await _loadScheduleArchiveMap();
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

    final prefs = await _prefs;
    await prefs.setString(_scheduleArchiveKey, json.encode(archive));

    if (makeActive) {
      await saveSemesterCode(semesterCode);
      if (rawScheduleJson != null) {
        await prefs.setString(_lastScheduleJsonKey, rawScheduleJson);
      }
      if (courses != null) {
        await prefs.setStringList(
          _coursesKey,
          courses.map((c) => json.encode(c.toJson())).toList(),
        );
      }
    }
  }

  Future<void> deleteSemesterArchive(String semesterCode) async {
    final archive = await _loadScheduleArchiveMap();
    archive.remove(semesterCode);

    final prefs = await _prefs;
    await prefs.setString(_scheduleArchiveKey, json.encode(archive));

    final overrides = await loadScheduleOverrides();
    final retainedOverrides =
        overrides.where((item) => item.semesterCode != semesterCode).toList();
    await prefs.setString(
      _scheduleOverridesKey,
      json.encode(retainedOverrides.map((item) => item.toJson()).toList()),
    );

    final activeSemester = await loadActiveSemesterCode();
    if (activeSemester == semesterCode) {
      final fallbackCodes =
          archive.keys.toList()..sort((a, b) => b.compareTo(a));
      if (fallbackCodes.isNotEmpty) {
        await saveActiveSemesterCode(fallbackCodes.first);
      } else {
        await prefs.remove(_activeSemesterKey);
      }
    }
  }

  Future<List<ScheduleOverride>> loadScheduleOverrides({
    String? semesterCode,
  }) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_scheduleOverridesKey);
    if (raw == null || raw.isEmpty) {
      return const <ScheduleOverride>[];
    }

    final decoded = json.decode(raw);
    if (decoded is! List) {
      return const <ScheduleOverride>[];
    }

    final activeSemester = semesterCode ?? await loadActiveSemesterCode();
    return decoded
        .whereType<Map>()
        .map(
          (item) => ScheduleOverride.fromJson(Map<String, dynamic>.from(item)),
        )
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
    final prefs = await _prefs;
    final raw = prefs.getString(_scheduleOverridesKey);
    final existing = <ScheduleOverride>[];

    if (raw != null && raw.isNotEmpty) {
      final decoded = json.decode(raw);
      if (decoded is List) {
        existing.addAll(
          decoded.whereType<Map>().map(
            (item) =>
                ScheduleOverride.fromJson(Map<String, dynamic>.from(item)),
          ),
        );
      }
    }

    final merged =
        existing.where((item) => item.semesterCode != semesterCode).toList()
          ..addAll(overrides);

    await prefs.setString(
      _scheduleOverridesKey,
      json.encode(merged.map((item) => item.toJson()).toList()),
    );
  }

  Future<SchoolTimeConfig> loadSchoolTimeConfig() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_schoolTimeConfigKey);
    if (raw == null || raw.isEmpty) {
      return SchoolTimeConfig.hainanuDefault();
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return SchoolTimeConfig.hainanuDefault();
      }
      final config = SchoolTimeConfig.fromJson(decoded);
      if (config.classTimes.isEmpty) {
        return SchoolTimeConfig.hainanuDefault();
      }
      return config;
    } catch (e) {
      AppLogger.warn('AppStorage', '读取课程时间配置失败，使用默认值', e);
      return SchoolTimeConfig.hainanuDefault();
    }
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
    final raw = prefs.getString(_schoolTimeGeneratorSettingsKey);
    if (raw == null || raw.isEmpty) {
      return SchoolTimeGeneratorSettings.defaults();
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return SchoolTimeGeneratorSettings.defaults();
      }
      return SchoolTimeGeneratorSettings.fromJson(decoded);
    } catch (e) {
      AppLogger.warn('AppStorage', '读取课程时间生成器设置失败，使用默认值', e);
      return SchoolTimeGeneratorSettings.defaults();
    }
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
      lastFetchTime: _readTime(prefs.getString(_lastFetchTimeKey)),
      lastAttemptTime: _readTime(prefs.getString(_lastAttemptTimeKey)),
      nextSyncTime: _readTime(prefs.getString(_nextSyncTimeKey)),
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
      await _secureStorage.write(key: _cookieSnapshotKey, value: cookieSnapshot);
      await prefs.remove(_cookieSnapshotKey);
    }
  }

  Future<void> saveLastFetchTime(DateTime time) async {
    final prefs = await _prefs;
    await prefs.setString(_lastFetchTimeKey, time.toIso8601String());
  }

  Future<void> saveCookieSnapshot(String cookie) async {
    await _secureStorage.write(key: _cookieSnapshotKey, value: cookie);
    // 清除旧的明文存储（迁移清理）
    final prefs = await _prefs;
    await prefs.remove(_cookieSnapshotKey);
  }

  Future<String?> loadCookieSnapshot() async {
    final secure = await _secureStorage.read(key: _cookieSnapshotKey);
    if (secure != null && secure.isNotEmpty) return secure;
    // 从旧版明文存储迁移
    final prefs = await _prefs;
    final legacy = prefs.getString(_cookieSnapshotKey);
    if (legacy != null && legacy.isNotEmpty) {
      await _secureStorage.write(key: _cookieSnapshotKey, value: legacy);
      await prefs.remove(_cookieSnapshotKey);
      return legacy;
    }
    return null;
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
      lastBuildTime: _readTime(prefs.getString(_reminderLastBuildTimeKey)),
      horizonEnd: _readTime(prefs.getString(_reminderHorizonEndKey)),
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

  static DateTime? _readTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  Future<Map<String, dynamic>> _loadScheduleArchiveMap() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_scheduleArchiveKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(decoded);
  }
}
