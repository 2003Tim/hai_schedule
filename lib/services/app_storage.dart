import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/models/storage_records.dart';
import 'package:hai_schedule/models/auto_sync_status_patch.dart';
import 'package:hai_schedule/utils/app_platform.dart';
import 'package:hai_schedule/utils/app_storage_codec.dart';
import 'package:hai_schedule/utils/app_storage_schema.dart';
import 'package:hai_schedule/utils/cookie_snapshot_store.dart';
import 'package:hai_schedule/utils/persist_retry.dart';

export '../models/storage_records.dart';
export '../models/auto_sync_status_patch.dart';

class AppStorage {
  AppStorage._();

  static final AppStorage instance = AppStorage._();
  @visibleForTesting
  static bool? debugForceAndroid;

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static final CookieSnapshotStore _cookieSnapshotStore = CookieSnapshotStore(
    secureStorage: _secureStorage,
    isAndroid: () => _isAndroid,
  );

  static const String _coursesKey = AppStorageSchema.coursesKey;
  static const String _displayDaysKey = AppStorageSchema.displayDaysKey;
  static const String _showNonCurrentWeekKey =
      AppStorageSchema.showNonCurrentWeekKey;

  static const String _lastFetchTimeKey = AppStorageSchema.lastFetchTimeKey;
  static const String _lastAttemptTimeKey = AppStorageSchema.lastAttemptTimeKey;
  static const String _lastErrorKey = AppStorageSchema.lastErrorKey;
  static const String _lastMessageKey = AppStorageSchema.lastMessageKey;
  static const String _lastStateKey = AppStorageSchema.lastStateKey;
  static const String _lastSourceKey = AppStorageSchema.lastSourceKey;
  static const String _lastDiffSummaryKey = AppStorageSchema.lastDiffSummaryKey;
  static const String _lastStateSemesterCodeKey =
      AppStorageSchema.lastStateSemesterCodeKey;
  static const String _nextSyncTimeKey = AppStorageSchema.nextSyncTimeKey;
  static const String _frequencyKey = AppStorageSchema.frequencyKey;
  static const String _customIntervalMinutesKey =
      AppStorageSchema.customIntervalMinutesKey;
  static const String _semesterKey = AppStorageSchema.semesterKey;
  static const String _legacySemesterKey = AppStorageSchema.legacySemesterKey;
  static const String _activeSemesterKey = AppStorageSchema.activeSemesterKey;
  static const String _scheduleArchiveKey = AppStorageSchema.scheduleArchiveKey;
  static const String _semesterCatalogKey = AppStorageSchema.semesterCatalogKey;
  static const String _semesterSyncRecordsKey =
      AppStorageSchema.semesterSyncRecordsKey;
  static const String _hasSyncedAtLeastOneSemesterKey =
      AppStorageSchema.hasSyncedAtLeastOneSemesterKey;
  static const String _scheduleOverridesKey =
      AppStorageSchema.scheduleOverridesKey;
  static const String _schoolTimeConfigKey =
      AppStorageSchema.schoolTimeConfigKey;
  static const String _schoolTimeGeneratorSettingsKey =
      AppStorageSchema.schoolTimeGeneratorSettingsKey;
  static const String _lastScheduleJsonKey =
      AppStorageSchema.lastScheduleJsonKey;
  static const String _cookieSnapshotKey = AppStorageSchema.cookieSnapshotKey;
  static const String _syncInvalidationFlagKey =
      AppStorageSchema.syncInvalidationFlagKey;
  static const String _syncWritingLockKey = AppStorageSchema.syncWritingLockKey;
  static const String _studentIdKey = AppStorageSchema.studentIdKey;
  static const String _reminderLeadTimeKey =
      AppStorageSchema.reminderLeadTimeKey;
  static const String _reminderLastBuildTimeKey =
      AppStorageSchema.reminderLastBuildTimeKey;
  static const String _reminderHorizonEndKey =
      AppStorageSchema.reminderHorizonEndKey;
  static const String _reminderScheduledCountKey =
      AppStorageSchema.reminderScheduledCountKey;
  static const String _reminderExactAlarmEnabledKey =
      AppStorageSchema.reminderExactAlarmEnabledKey;

  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get _prefs =>
      _prefsFuture ??= SharedPreferences.getInstance();

  static bool get _isAndroid => debugForceAndroid ?? AppPlatform.instance.isAndroid;

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

  Future<String?> loadActiveSemesterCode() async {
    final prefs = await _reloadedPrefs();
    return _readActiveSemesterCode(prefs);
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

  Future<List<SemesterOption>> loadSemesterCatalog() async {
    final prefs = await _reloadedPrefs();
    final rawItems = prefs.getStringList(_semesterCatalogKey);
    if (rawItems != null) {
      try {
        return _decodeSemesterCatalogItems(rawItems.map(json.decode));
      } catch (_) {
        return const <SemesterOption>[];
      }
    }

    final legacyRaw = prefs.getString(_semesterCatalogKey);
    if (legacyRaw == null || legacyRaw.isEmpty) {
      return const <SemesterOption>[];
    }

    try {
      final decoded = json.decode(legacyRaw);
      if (decoded is! List) {
        return const <SemesterOption>[];
      }
      return _decodeSemesterCatalogItems(decoded);
    } catch (_) {
      return const <SemesterOption>[];
    }
  }

  Future<List<SemesterOption>> loadKnownSemesterOptions() =>
      loadSemesterCatalog();

  Future<void> saveSemesterCatalog(List<SemesterOption> options) async {
    final prefs = await _prefs;
    final encodedItems = options
        .where((item) => item.isValid)
        .map((item) => json.encode(item.toJson()))
        .toList(growable: false);
    await PersistRetry.run(
      description: '学期目录',
      maxAttempts: 4,
      delay: const Duration(milliseconds: 200),
      write: () => prefs.setStringList(_semesterCatalogKey, encodedItems),
      verify: () async {
        await prefs.reload();
        return _sameStringList(
          prefs.getStringList(_semesterCatalogKey),
          encodedItems,
        );
      },
    );
  }

  Future<void> saveKnownSemesterOptions(List<SemesterOption> options) =>
      saveSemesterCatalog(options);

  List<SemesterOption> _decodeSemesterCatalogItems(Iterable<dynamic> items) {
    return items
        .whereType<Map>()
        .map((item) => SemesterOption.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.isValid)
        .toList();
  }

  bool _sameStringList(List<String>? left, List<String> right) {
    if (left == null || left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  Future<bool> loadHasSyncedAtLeastOneSemester() async {
    final prefs = await _reloadedPrefs();
    final stored = prefs.getBool(_hasSyncedAtLeastOneSemesterKey);
    if (stored != null) {
      return stored;
    }

    final migrated = await _migrateHasSyncedAtLeastOneSemester(prefs);
    return migrated;
  }

  Future<void> saveHasSyncedAtLeastOneSemester(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(_hasSyncedAtLeastOneSemesterKey, value);
  }

  Future<SemesterSyncRecord?> loadSemesterSyncRecord(
    String semesterCode,
  ) async {
    final prefs = await _reloadedPrefs();
    await _migrateLegacySemesterSyncRecord(prefs, semesterCode: semesterCode);
    final records = AppStorageCodec.decodeSemesterSyncRecordMap(
      prefs.getString(_semesterSyncRecordsKey),
    );
    return records[semesterCode];
  }

  Future<void> saveSemesterSyncRecord({
    required String semesterCode,
    required int count,
    required DateTime lastSyncTime,
  }) async {
    final prefs = await _reloadedPrefs();
    final records = AppStorageCodec.decodeSemesterSyncRecordMap(
      prefs.getString(_semesterSyncRecordsKey),
    );
    records[semesterCode] = SemesterSyncRecord(
      count: count,
      lastSyncTime: lastSyncTime,
    );
    await prefs.setString(
      _semesterSyncRecordsKey,
      AppStorageCodec.encodeSemesterSyncRecordMap(records),
    );
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

    final syncRecords = AppStorageCodec.decodeSemesterSyncRecordMap(
      prefs.getString(_semesterSyncRecordsKey),
    );
    if (syncRecords.remove(semesterCode) != null) {
      await prefs.setString(
        _semesterSyncRecordsKey,
        AppStorageCodec.encodeSemesterSyncRecordMap(syncRecords),
      );
    }

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

  Future<StoredAutoSyncRecord> loadAutoSyncRecord({
    String? semesterCode,
  }) async {
    final prefs = await _reloadedPrefs();
    final resolvedSemester =
        semesterCode?.trim().isNotEmpty == true
            ? semesterCode!.trim()
            : _readActiveSemesterCode(prefs);
    await _migrateLegacySemesterSyncRecord(
      prefs,
      semesterCode: resolvedSemester,
    );

    final semesterSyncRecord =
        resolvedSemester == null || resolvedSemester.isEmpty
            ? null
            : AppStorageCodec.decodeSemesterSyncRecordMap(
              prefs.getString(_semesterSyncRecordsKey),
            )[resolvedSemester];
    final stateSemesterCode = prefs.getString(_lastStateSemesterCodeKey);
    final stateMatchesActive =
        resolvedSemester != null &&
        resolvedSemester.isNotEmpty &&
        stateSemesterCode == resolvedSemester;

    return StoredAutoSyncRecord(
      frequency: prefs.getString(_frequencyKey) ?? 'daily',
      customIntervalMinutes: prefs.getInt(_customIntervalMinutesKey),
      lastFetchTime: semesterSyncRecord?.lastSyncTime,
      lastAttemptTime:
          stateMatchesActive
              ? AppStorageCodec.readTime(prefs.getString(_lastAttemptTimeKey))
              : null,
      nextSyncTime: AppStorageCodec.readTime(prefs.getString(_nextSyncTimeKey)),
      state:
          stateMatchesActive
              ? prefs.getString(_lastStateKey)
              : semesterSyncRecord != null
              ? 'success'
              : 'idle',
      message:
          stateMatchesActive
              ? prefs.getString(_lastMessageKey)
              : semesterSyncRecord != null
              ? '当前学期已同步 ${semesterSyncRecord.count} 门课程'
              : '当前学期未同步',
      lastError: stateMatchesActive ? prefs.getString(_lastErrorKey) : null,
      lastSource: stateMatchesActive ? prefs.getString(_lastSourceKey) : null,
      lastDiffSummary:
          stateMatchesActive ? prefs.getString(_lastDiffSummaryKey) : null,
      semesterCode: resolvedSemester,
      stateSemesterCode: stateSemesterCode,
      cookieSnapshot: await loadCookieSnapshot(),
      rawScheduleJson: prefs.getString(_lastScheduleJsonKey),
      semesterSyncRecord: semesterSyncRecord,
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

  Future<void> applyAutoSyncStatusPatch(AutoSyncStatusPatch patch) async {
    if (!patch.hasAnyChange) return;
    final prefs = await _prefs;
    final resolvedSemester =
        patch.semesterCode?.trim().isNotEmpty == true
            ? patch.semesterCode!.trim()
            : _readActiveSemesterCode(prefs);

    await _writeOptionalString(prefs, _lastStateKey, patch.state);
    await _writeOptionalString(prefs, _lastMessageKey, patch.message);
    await _writeOptionalString(prefs, _lastSourceKey, patch.source);

    await _writeOrClearString(
      prefs,
      _lastDiffSummaryKey,
      value: patch.diffSummary,
      clear: patch.clearDiffSummary,
    );
    await _writeOrClearString(
      prefs,
      _lastErrorKey,
      value: patch.error,
      clear: patch.clearError,
    );

    if (patch.lastFetchTime != null) {
      await prefs.setString(
        _lastFetchTimeKey,
        patch.lastFetchTime!.toIso8601String(),
      );
    }

    if (resolvedSemester != null && resolvedSemester.isNotEmpty) {
      await prefs.setString(_lastStateSemesterCodeKey, resolvedSemester);
    } else if (patch.state != null ||
        patch.message != null ||
        patch.source != null ||
        patch.diffSummary != null ||
        patch.error != null ||
        patch.clearError ||
        patch.clearDiffSummary ||
        patch.lastFetchTime != null ||
        patch.lastAttemptTime != null) {
      await prefs.remove(_lastStateSemesterCodeKey);
    }

    if (patch.lastAttemptTime != null) {
      await prefs.setString(
        _lastAttemptTimeKey,
        patch.lastAttemptTime!.toIso8601String(),
      );
    }

    await _writeOrClearString(
      prefs,
      _nextSyncTimeKey,
      value: patch.nextSyncTime?.toIso8601String(),
      clear: patch.clearNextSyncTime,
    );

    if (patch.cookieSnapshot != null) {
      await _persistCookieSnapshot(patch.cookieSnapshot!);
      await prefs.remove(_cookieSnapshotKey);
    }
  }

  /// Backwards-compatible wrapper retained for legacy callers and tests that
  /// still invoke the wide-keyword API. New code should construct an
  /// [AutoSyncStatusPatch] and call [applyAutoSyncStatusPatch] directly.
  Future<void> saveAutoSyncRecord({
    String? state,
    String? message,
    String? source,
    String? diffSummary,
    String? error,
    String? semesterCode,
    bool clearError = false,
    bool clearDiffSummary = false,
    DateTime? lastFetchTime,
    DateTime? lastAttemptTime,
    DateTime? nextSyncTime,
    bool clearNextSyncTime = false,
    String? cookieSnapshot,
  }) {
    return applyAutoSyncStatusPatch(
      AutoSyncStatusPatch(
        state: state,
        message: message,
        source: source,
        diffSummary: diffSummary,
        error: error,
        semesterCode: semesterCode,
        cookieSnapshot: cookieSnapshot,
        lastFetchTime: lastFetchTime,
        lastAttemptTime: lastAttemptTime,
        nextSyncTime: nextSyncTime,
        clearError: clearError,
        clearDiffSummary: clearDiffSummary,
        clearNextSyncTime: clearNextSyncTime,
      ),
    );
  }

  Future<void> _writeOptionalString(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null) return;
    await prefs.setString(key, value);
  }

  Future<void> _writeOrClearString(
    SharedPreferences prefs,
    String key, {
    required String? value,
    required bool clear,
  }) async {
    if (value != null) {
      await prefs.setString(key, value);
    } else if (clear) {
      await prefs.remove(key);
    }
  }

  Future<void> saveLastFetchTime(DateTime time) async {
    final prefs = await _prefs;
    await prefs.setString(_lastFetchTimeKey, time.toIso8601String());
  }

  Future<void> saveCookieSnapshot(String cookie) async {
    await _cookieSnapshotStore.persist(cookie);
    final prefs = await _prefs;
    await prefs.remove(_cookieSnapshotKey);
    await prefs.remove(_syncInvalidationFlagKey);
  }

  Future<bool> loadSyncInvalidationFlag() async {
    final prefs = await _reloadedPrefs();
    return prefs.getBool(_syncInvalidationFlagKey) ?? false;
  }

  Future<void> setSyncInvalidationFlag(bool value) async {
    final prefs = await _prefs;
    if (value) {
      await prefs.setBool(_syncInvalidationFlagKey, true);
      return;
    }
    await prefs.remove(_syncInvalidationFlagKey);
  }

  Future<void> clearSyncInvalidationFlag() => setSyncInvalidationFlag(false);

  Future<bool> loadSyncWritingLock() async {
    final prefs = await _reloadedPrefs();
    return prefs.getBool(_syncWritingLockKey) ?? false;
  }

  Future<void> setSyncWritingLock(bool value) async {
    final prefs = await _prefs;
    if (value) {
      await prefs.setBool(_syncWritingLockKey, true);
      return;
    }
    await prefs.remove(_syncWritingLockKey);
  }

  Future<String?> loadCookieSnapshot() => _cookieSnapshotStore.load();

  Future<void> clearCookieSnapshot({bool strict = false}) =>
      _cookieSnapshotStore.clear(strict: strict);

  Future<void> saveStudentId(String studentId) async {
    await _secureStorage.write(key: _studentIdKey, value: studentId);
  }

  Future<String?> loadStudentId() async {
    final secure = await _secureStorage.read(key: _studentIdKey);
    if (secure != null) return secure;
    // 迁移旧版明文存储
    final prefs = await _prefs;
    final plain = prefs.getString(_studentIdKey);
    if (plain != null) {
      await _secureStorage.write(key: _studentIdKey, value: plain);
      await prefs.remove(_studentIdKey);
    }
    return plain;
  }

  Future<StoredReminderRecord> loadReminderRecord() async {
    final prefs = await _prefs;
    await prefs.reload();
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
    if (_isAndroid) await prefs.reload();
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

  Future<void> _migrateLegacySemesterSyncRecord(
    SharedPreferences prefs, {
    String? semesterCode,
  }) async {
    final resolvedSemester = semesterCode ?? _readActiveSemesterCode(prefs);
    if (resolvedSemester == null || resolvedSemester.isEmpty) {
      return;
    }

    final records = AppStorageCodec.decodeSemesterSyncRecordMap(
      prefs.getString(_semesterSyncRecordsKey),
    );
    if (records.containsKey(resolvedSemester)) {
      return;
    }

    final lastFetchTime = AppStorageCodec.readTime(
      prefs.getString(_lastFetchTimeKey),
    );
    if (lastFetchTime == null) {
      return;
    }

    final archive = await _loadScheduleArchiveMapFromPrefs(prefs);
    final storedSemester = AppStorageCodec.readSemesterArchive(
      archive,
      resolvedSemester,
    );
    final count =
        storedSemester?.courses.length ??
        AppStorageCodec.decodeGlobalCourseMirror(
          prefs.getStringList(_coursesKey),
        ).length;
    records[resolvedSemester] = SemesterSyncRecord(
      count: count,
      lastSyncTime: lastFetchTime,
    );
    await prefs.setString(
      _semesterSyncRecordsKey,
      AppStorageCodec.encodeSemesterSyncRecordMap(records),
    );
    await prefs.setString(_lastStateSemesterCodeKey, resolvedSemester);
  }

  Future<bool> _migrateHasSyncedAtLeastOneSemester(
    SharedPreferences prefs,
  ) async {
    final hasSemesterArchives =
        AppStorageCodec.decodeScheduleArchiveMap(
          prefs.getString(_scheduleArchiveKey),
        ).isNotEmpty;
    final hasSyncRecords =
        AppStorageCodec.decodeSemesterSyncRecordMap(
          prefs.getString(_semesterSyncRecordsKey),
        ).isNotEmpty;
    final hasSuccessfulFetch =
        AppStorageCodec.readTime(prefs.getString(_lastFetchTimeKey)) != null;
    final hasSuccessfulState = prefs.getString(_lastStateKey) == 'success';

    final migrated =
        hasSemesterArchives ||
        hasSyncRecords ||
        hasSuccessfulFetch ||
        hasSuccessfulState;
    await prefs.setBool(_hasSyncedAtLeastOneSemesterKey, migrated);
    return migrated;
  }

  Future<void> _persistCookieSnapshot(String cookie) async {
    await _cookieSnapshotStore.persist(cookie);
    final prefs = await _prefs;
    await prefs.remove(_syncInvalidationFlagKey);
  }
}
