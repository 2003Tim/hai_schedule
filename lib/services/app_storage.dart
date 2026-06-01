import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_source.dart';
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
  static const String _activeScheduleSourceKey =
      AppStorageSchema.activeScheduleSourceKey;

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

  static bool get _isAndroid =>
      debugForceAndroid ?? AppPlatform.instance.isAndroid;

  static String _sourceScopedKey(String key, ScheduleSource source) =>
      source.isGraduate ? key : '${source.value}.$key';

  static String _keyForPrefs(SharedPreferences prefs, String key) =>
      _sourceScopedKey(key, _readActiveScheduleSource(prefs));

  static ScheduleSource _readActiveScheduleSource(SharedPreferences prefs) =>
      ScheduleSource.fromValue(prefs.getString(_activeScheduleSourceKey));

  void resetForTesting() {
    _prefsFuture = null;
  }

  Future<ScheduleSource> loadActiveScheduleSource() async {
    final prefs = await _reloadedPrefs();
    return _readActiveScheduleSource(prefs);
  }

  Future<void> saveActiveScheduleSource(ScheduleSource source) async {
    final prefs = await _prefs;
    await prefs.setString(_activeScheduleSourceKey, source.value);
  }

  Future<List<Course>> loadCourses() async {
    final prefs = await _reloadedPrefs();
    final coursesKey = _keyForPrefs(prefs, _coursesKey);
    final activeSemester = _readActiveSemesterCode(prefs);
    if (activeSemester != null && activeSemester.isNotEmpty) {
      final archive = AppStorageCodec.readSemesterArchive(
        await _loadScheduleArchiveMapFromPrefs(prefs),
        activeSemester,
      );
      return archive?.courses ?? const <Course>[];
    }

    return AppStorageCodec.decodeGlobalCourseMirror(
      prefs.getStringList(coursesKey),
    );
  }

  Future<void> saveCourses(List<Course> courses) async {
    final prefs = await _prefs;
    final coursesKey = _keyForPrefs(prefs, _coursesKey);
    final jsonList =
        courses.map((course) => json.encode(course.toJson())).toList();
    await prefs.setStringList(coursesKey, jsonList);

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

    return prefs.getString(_keyForPrefs(prefs, _lastScheduleJsonKey));
  }

  Future<void> saveRawScheduleJson(String jsonValue) async {
    final prefs = await _prefs;
    await prefs.setString(_keyForPrefs(prefs, _lastScheduleJsonKey), jsonValue);

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
      prefs.getString(_keyForPrefs(prefs, _scheduleArchiveKey)),
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
    final semesterCatalogKey = _keyForPrefs(prefs, _semesterCatalogKey);
    final rawItems = prefs.getStringList(semesterCatalogKey);
    if (rawItems != null) {
      try {
        return _decodeSemesterCatalogItems(rawItems.map(json.decode));
      } catch (_) {
        return const <SemesterOption>[];
      }
    }

    final legacyRaw = prefs.getString(semesterCatalogKey);
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
    final semesterCatalogKey = _keyForPrefs(prefs, _semesterCatalogKey);
    final encodedItems = options
        .where((item) => item.isValid)
        .map((item) => json.encode(item.toJson()))
        .toList(growable: false);
    await PersistRetry.run(
      description: '学期目录',
      maxAttempts: 4,
      delay: const Duration(milliseconds: 200),
      write: () => prefs.setStringList(semesterCatalogKey, encodedItems),
      verify: () async {
        await prefs.reload();
        return _sameStringList(
          prefs.getStringList(semesterCatalogKey),
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
    final hasSyncedKey = _keyForPrefs(prefs, _hasSyncedAtLeastOneSemesterKey);
    final stored = prefs.getBool(hasSyncedKey);
    if (stored != null) {
      return stored;
    }

    final migrated = await _migrateHasSyncedAtLeastOneSemester(prefs);
    return migrated;
  }

  Future<void> saveHasSyncedAtLeastOneSemester(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool(
      _keyForPrefs(prefs, _hasSyncedAtLeastOneSemesterKey),
      value,
    );
  }

  Future<SemesterSyncRecord?> loadSemesterSyncRecord(
    String semesterCode,
  ) async {
    final prefs = await _reloadedPrefs();
    await _migrateLegacySemesterSyncRecord(prefs, semesterCode: semesterCode);
    final semesterSyncRecordsKey = _keyForPrefs(prefs, _semesterSyncRecordsKey);
    final records = AppStorageCodec.decodeSemesterSyncRecordMap(
      prefs.getString(semesterSyncRecordsKey),
    );
    return records[semesterCode];
  }

  Future<void> saveSemesterSyncRecord({
    required String semesterCode,
    required int count,
    required DateTime lastSyncTime,
  }) async {
    final prefs = await _reloadedPrefs();
    final semesterSyncRecordsKey = _keyForPrefs(prefs, _semesterSyncRecordsKey);
    final records = AppStorageCodec.decodeSemesterSyncRecordMap(
      prefs.getString(semesterSyncRecordsKey),
    );
    records[semesterCode] = SemesterSyncRecord(
      count: count,
      lastSyncTime: lastSyncTime,
    );
    await prefs.setString(
      semesterSyncRecordsKey,
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
    final scheduleArchiveKey = _keyForPrefs(prefs, _scheduleArchiveKey);
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
      scheduleArchiveKey,
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
    final semesterSyncRecordsKey = _keyForPrefs(prefs, _semesterSyncRecordsKey);
    final scheduleOverridesKey = _keyForPrefs(prefs, _scheduleOverridesKey);
    archive.remove(semesterCode);

    await prefs.setString(
      _keyForPrefs(prefs, _scheduleArchiveKey),
      AppStorageCodec.encodeScheduleArchiveMap(archive),
    );

    final syncRecords = AppStorageCodec.decodeSemesterSyncRecordMap(
      prefs.getString(semesterSyncRecordsKey),
    );
    if (syncRecords.remove(semesterCode) != null) {
      await prefs.setString(
        semesterSyncRecordsKey,
        AppStorageCodec.encodeSemesterSyncRecordMap(syncRecords),
      );
    }

    final overrides = AppStorageCodec.decodeScheduleOverrides(
      prefs.getString(scheduleOverridesKey),
    );
    final retainedOverrides =
        overrides.where((item) => item.semesterCode != semesterCode).toList();
    await prefs.setString(
      scheduleOverridesKey,
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
      prefs.getString(_keyForPrefs(prefs, _scheduleOverridesKey)),
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
    final scheduleOverridesKey = _keyForPrefs(prefs, _scheduleOverridesKey);
    final existing = AppStorageCodec.decodeScheduleOverrides(
      prefs.getString(scheduleOverridesKey),
    );

    final merged =
        existing.where((item) => item.semesterCode != semesterCode).toList()
          ..addAll(overrides);

    await prefs.setString(
      scheduleOverridesKey,
      AppStorageCodec.encodeScheduleOverrides(merged),
    );
  }

  Future<SchoolTimeConfig> loadSchoolTimeConfig() async {
    final prefs = await _prefs;
    return AppStorageCodec.decodeSchoolTimeConfig(
      prefs.getString(_keyForPrefs(prefs, _schoolTimeConfigKey)),
    );
  }

  Future<void> saveSchoolTimeConfig(SchoolTimeConfig config) async {
    final prefs = await _prefs;
    await prefs.setString(
      _keyForPrefs(prefs, _schoolTimeConfigKey),
      json.encode(config.toJson()),
    );
  }

  Future<void> clearSchoolTimeConfig() async {
    final prefs = await _prefs;
    await prefs.remove(_keyForPrefs(prefs, _schoolTimeConfigKey));
    await prefs.remove(_keyForPrefs(prefs, _schoolTimeGeneratorSettingsKey));
  }

  Future<SchoolTimeGeneratorSettings> loadSchoolTimeGeneratorSettings() async {
    final prefs = await _prefs;
    return AppStorageCodec.decodeSchoolTimeGeneratorSettings(
      prefs.getString(_keyForPrefs(prefs, _schoolTimeGeneratorSettingsKey)),
    );
  }

  Future<void> saveSchoolTimeGeneratorSettings(
    SchoolTimeGeneratorSettings settings,
  ) async {
    final prefs = await _prefs;
    await prefs.setString(
      _keyForPrefs(prefs, _schoolTimeGeneratorSettingsKey),
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
    final semesterSyncRecordsKey = _keyForPrefs(prefs, _semesterSyncRecordsKey);
    final lastStateSemesterCodeKey = _keyForPrefs(
      prefs,
      _lastStateSemesterCodeKey,
    );
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
              prefs.getString(semesterSyncRecordsKey),
            )[resolvedSemester];
    final stateSemesterCode = prefs.getString(lastStateSemesterCodeKey);
    final stateMatchesActive =
        resolvedSemester != null &&
        resolvedSemester.isNotEmpty &&
        stateSemesterCode == resolvedSemester;

    return StoredAutoSyncRecord(
      frequency: prefs.getString(_keyForPrefs(prefs, _frequencyKey)) ?? 'daily',
      customIntervalMinutes: prefs.getInt(
        _keyForPrefs(prefs, _customIntervalMinutesKey),
      ),
      lastFetchTime: semesterSyncRecord?.lastSyncTime,
      lastAttemptTime:
          stateMatchesActive
              ? AppStorageCodec.readTime(
                prefs.getString(_keyForPrefs(prefs, _lastAttemptTimeKey)),
              )
              : null,
      nextSyncTime: AppStorageCodec.readTime(
        prefs.getString(_keyForPrefs(prefs, _nextSyncTimeKey)),
      ),
      state:
          stateMatchesActive
              ? prefs.getString(_keyForPrefs(prefs, _lastStateKey))
              : semesterSyncRecord != null
              ? 'success'
              : 'idle',
      message:
          stateMatchesActive
              ? prefs.getString(_keyForPrefs(prefs, _lastMessageKey))
              : semesterSyncRecord != null
              ? '当前学期已同步 ${semesterSyncRecord.count} 门课程'
              : '当前学期未同步',
      lastError:
          stateMatchesActive
              ? prefs.getString(_keyForPrefs(prefs, _lastErrorKey))
              : null,
      lastSource:
          stateMatchesActive
              ? prefs.getString(_keyForPrefs(prefs, _lastSourceKey))
              : null,
      lastDiffSummary:
          stateMatchesActive
              ? prefs.getString(_keyForPrefs(prefs, _lastDiffSummaryKey))
              : null,
      semesterCode: resolvedSemester,
      stateSemesterCode: stateSemesterCode,
      cookieSnapshot: await loadCookieSnapshot(),
      rawScheduleJson: prefs.getString(
        _keyForPrefs(prefs, _lastScheduleJsonKey),
      ),
      semesterSyncRecord: semesterSyncRecord,
    );
  }

  Future<void> saveAutoSyncSettings(
    String frequency, {
    int? customIntervalMinutes,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_keyForPrefs(prefs, _frequencyKey), frequency);
    final customIntervalMinutesKey = _keyForPrefs(
      prefs,
      _customIntervalMinutesKey,
    );
    if (customIntervalMinutes != null) {
      await prefs.setInt(customIntervalMinutesKey, customIntervalMinutes);
    } else if (frequency != 'custom') {
      await prefs.remove(customIntervalMinutesKey);
    }
  }

  Future<void> applyAutoSyncStatusPatch(AutoSyncStatusPatch patch) async {
    if (!patch.hasAnyChange) return;
    final prefs = await _prefs;
    final lastStateKey = _keyForPrefs(prefs, _lastStateKey);
    final lastMessageKey = _keyForPrefs(prefs, _lastMessageKey);
    final lastSourceKey = _keyForPrefs(prefs, _lastSourceKey);
    final lastDiffSummaryKey = _keyForPrefs(prefs, _lastDiffSummaryKey);
    final lastErrorKey = _keyForPrefs(prefs, _lastErrorKey);
    final lastFetchTimeKey = _keyForPrefs(prefs, _lastFetchTimeKey);
    final lastAttemptTimeKey = _keyForPrefs(prefs, _lastAttemptTimeKey);
    final lastStateSemesterCodeKey = _keyForPrefs(
      prefs,
      _lastStateSemesterCodeKey,
    );
    final nextSyncTimeKey = _keyForPrefs(prefs, _nextSyncTimeKey);
    final cookieSnapshotKey = _keyForPrefs(prefs, _cookieSnapshotKey);
    final resolvedSemester =
        patch.semesterCode?.trim().isNotEmpty == true
            ? patch.semesterCode!.trim()
            : _readActiveSemesterCode(prefs);

    await _writeOptionalString(prefs, lastStateKey, patch.state);
    await _writeOptionalString(prefs, lastMessageKey, patch.message);
    await _writeOptionalString(prefs, lastSourceKey, patch.source);

    await _writeOrClearString(
      prefs,
      lastDiffSummaryKey,
      value: patch.diffSummary,
      clear: patch.clearDiffSummary,
    );
    await _writeOrClearString(
      prefs,
      lastErrorKey,
      value: patch.error,
      clear: patch.clearError,
    );

    if (patch.lastFetchTime != null) {
      await prefs.setString(
        lastFetchTimeKey,
        patch.lastFetchTime!.toIso8601String(),
      );
    }

    if (resolvedSemester != null && resolvedSemester.isNotEmpty) {
      await prefs.setString(lastStateSemesterCodeKey, resolvedSemester);
    } else if (patch.state != null ||
        patch.message != null ||
        patch.source != null ||
        patch.diffSummary != null ||
        patch.error != null ||
        patch.clearError ||
        patch.clearDiffSummary ||
        patch.lastFetchTime != null ||
        patch.lastAttemptTime != null) {
      await prefs.remove(lastStateSemesterCodeKey);
    }

    if (patch.lastAttemptTime != null) {
      await prefs.setString(
        lastAttemptTimeKey,
        patch.lastAttemptTime!.toIso8601String(),
      );
    }

    await _writeOrClearString(
      prefs,
      nextSyncTimeKey,
      value: patch.nextSyncTime?.toIso8601String(),
      clear: patch.clearNextSyncTime,
    );

    if (patch.cookieSnapshot != null) {
      // #C3: persist the cookie under the source the patch was created for
      // (not whatever source is active at write time). Falls back to the
      // active source only when the patch did not specify one.
      await _persistCookieSnapshot(
        patch.cookieSnapshot!,
        overrideSource: patch.cookieSource,
      );
      await prefs.remove(cookieSnapshotKey);
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
    ScheduleSource? cookieSource,
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
        cookieSource: cookieSource,
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
    await prefs.setString(
      _keyForPrefs(prefs, _lastFetchTimeKey),
      time.toIso8601String(),
    );
  }

  Future<void> saveCookieSnapshot(String cookie) async {
    final prefs = await _prefs;
    final source = _readActiveScheduleSource(prefs);
    await _cookieSnapshotStore.persist(cookie, source: source);
    await prefs.remove(_sourceScopedKey(_cookieSnapshotKey, source));
    await prefs.remove(_sourceScopedKey(_syncInvalidationFlagKey, source));
  }

  Future<bool> loadSyncInvalidationFlag() async {
    final prefs = await _reloadedPrefs();
    return prefs.getBool(_keyForPrefs(prefs, _syncInvalidationFlagKey)) ??
        false;
  }

  Future<void> setSyncInvalidationFlag(bool value) async {
    final prefs = await _prefs;
    final syncInvalidationFlagKey = _keyForPrefs(
      prefs,
      _syncInvalidationFlagKey,
    );
    if (value) {
      await prefs.setBool(syncInvalidationFlagKey, true);
      return;
    }
    await prefs.remove(syncInvalidationFlagKey);
  }

  Future<void> clearSyncInvalidationFlag() => setSyncInvalidationFlag(false);

  Future<bool> loadSyncWritingLock() async {
    final prefs = await _reloadedPrefs();
    return prefs.getBool(_keyForPrefs(prefs, _syncWritingLockKey)) ?? false;
  }

  Future<void> setSyncWritingLock(bool value) async {
    final prefs = await _prefs;
    final syncWritingLockKey = _keyForPrefs(prefs, _syncWritingLockKey);
    if (value) {
      await prefs.setBool(syncWritingLockKey, true);
      return;
    }
    await prefs.remove(syncWritingLockKey);
  }

  Future<String?> loadCookieSnapshot() async {
    final prefs = await _prefs;
    return _cookieSnapshotStore.load(source: _readActiveScheduleSource(prefs));
  }

  Future<void> clearCookieSnapshot({bool strict = false}) async {
    final prefs = await _prefs;
    await _cookieSnapshotStore.clear(
      strict: strict,
      source: _readActiveScheduleSource(prefs),
    );
  }

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
    // #P2: previously this unconditionally called `prefs.reload()` on
    // Android, which re-parses the entire on-disk XML file (archive,
    // rawScheduleJson, cookie, etc.) on EVERY read. With ~6+ reads on
    // the startup path alone, this dominates cold-start time.
    //
    // SharedPreferences already maintains an in-memory cache that is
    // updated by every setX() call (including the writes this class
    // performs). Within-process reads therefore see the freshest values
    // without reload().
    //
    // Cross-process writes from the native side (e.g. AutoSyncScheduler
    // setting sync_invalidation_flag from a BroadcastReceiver) are picked
    // up on the next app launch, or by callers that explicitly call
    // [SharedPreferences.reload] (see [saveSemesterSyncRecord] and the
    // reminder record flow which already do this).
    final prefs = await _prefs;
    return prefs;
  }

  String? _readSemesterCode(SharedPreferences prefs) {
    return prefs.getString(_keyForPrefs(prefs, _semesterKey)) ??
        prefs.getString(_keyForPrefs(prefs, _legacySemesterKey));
  }

  String? _readActiveSemesterCode(SharedPreferences prefs) {
    return prefs.getString(_keyForPrefs(prefs, _activeSemesterKey)) ??
        _readSemesterCode(prefs);
  }

  Future<void> _applyActiveSemesterSnapshot(
    SharedPreferences prefs, {
    String? semesterCode,
    Map<String, dynamic>? entry,
  }) async {
    final activeSemesterKey = _keyForPrefs(prefs, _activeSemesterKey);
    final semesterKey = _keyForPrefs(prefs, _semesterKey);
    final legacySemesterKey = _keyForPrefs(prefs, _legacySemesterKey);
    final lastScheduleJsonKey = _keyForPrefs(prefs, _lastScheduleJsonKey);
    final coursesKey = _keyForPrefs(prefs, _coursesKey);
    if (semesterCode == null || semesterCode.isEmpty) {
      await prefs.remove(activeSemesterKey);
      await prefs.remove(semesterKey);
      await prefs.remove(legacySemesterKey);
      await prefs.remove(lastScheduleJsonKey);
      await prefs.remove(coursesKey);
      return;
    }

    await prefs.setString(activeSemesterKey, semesterCode);
    await prefs.setString(semesterKey, semesterCode);
    await prefs.setString(legacySemesterKey, semesterCode);

    final rawScheduleJson = entry?['rawScheduleJson'] as String?;
    if (rawScheduleJson != null && rawScheduleJson.isNotEmpty) {
      await prefs.setString(lastScheduleJsonKey, rawScheduleJson);
    } else {
      await prefs.remove(lastScheduleJsonKey);
    }

    final mirroredCourses = AppStorageCodec.encodeMirroredCourses(entry);
    if (mirroredCourses != null) {
      await prefs.setStringList(coursesKey, mirroredCourses);
    } else {
      await prefs.remove(coursesKey);
    }
  }

  Future<Map<String, dynamic>> _loadScheduleArchiveMapFromPrefs(
    SharedPreferences prefs,
  ) async {
    return AppStorageCodec.decodeScheduleArchiveMap(
      prefs.getString(_keyForPrefs(prefs, _scheduleArchiveKey)),
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
    final semesterSyncRecordsKey = _keyForPrefs(prefs, _semesterSyncRecordsKey);
    final lastFetchTimeKey = _keyForPrefs(prefs, _lastFetchTimeKey);
    final coursesKey = _keyForPrefs(prefs, _coursesKey);
    final lastStateSemesterCodeKey = _keyForPrefs(
      prefs,
      _lastStateSemesterCodeKey,
    );

    final records = AppStorageCodec.decodeSemesterSyncRecordMap(
      prefs.getString(semesterSyncRecordsKey),
    );
    if (records.containsKey(resolvedSemester)) {
      return;
    }

    final lastFetchTime = AppStorageCodec.readTime(
      prefs.getString(lastFetchTimeKey),
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
          prefs.getStringList(coursesKey),
        ).length;
    records[resolvedSemester] = SemesterSyncRecord(
      count: count,
      lastSyncTime: lastFetchTime,
    );
    await prefs.setString(
      semesterSyncRecordsKey,
      AppStorageCodec.encodeSemesterSyncRecordMap(records),
    );
    await prefs.setString(lastStateSemesterCodeKey, resolvedSemester);
  }

  Future<bool> _migrateHasSyncedAtLeastOneSemester(
    SharedPreferences prefs,
  ) async {
    final hasSyncedKey = _keyForPrefs(prefs, _hasSyncedAtLeastOneSemesterKey);
    final hasSemesterArchives =
        AppStorageCodec.decodeScheduleArchiveMap(
          prefs.getString(_keyForPrefs(prefs, _scheduleArchiveKey)),
        ).isNotEmpty;
    final hasSyncRecords =
        AppStorageCodec.decodeSemesterSyncRecordMap(
          prefs.getString(_keyForPrefs(prefs, _semesterSyncRecordsKey)),
        ).isNotEmpty;
    final hasSuccessfulFetch =
        AppStorageCodec.readTime(
          prefs.getString(_keyForPrefs(prefs, _lastFetchTimeKey)),
        ) !=
        null;
    final hasSuccessfulState =
        prefs.getString(_keyForPrefs(prefs, _lastStateKey)) == 'success';

    final migrated =
        hasSemesterArchives ||
        hasSyncRecords ||
        hasSuccessfulFetch ||
        hasSuccessfulState;
    await prefs.setBool(hasSyncedKey, migrated);
    return migrated;
  }

  Future<void> _persistCookieSnapshot(
    String cookie, {
    ScheduleSource? overrideSource,
  }) async {
    final prefs = await _prefs;
    final source = overrideSource ?? _readActiveScheduleSource(prefs);
    await _cookieSnapshotStore.persist(cookie, source: source);
    await prefs.remove(_sourceScopedKey(_syncInvalidationFlagKey, source));
  }
}
