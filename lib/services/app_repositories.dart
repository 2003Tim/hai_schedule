import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/class_silence_store.dart';
import 'package:hai_schedule/services/app_storage.dart';

class ScheduleCache {
  final List<Course> courses;
  final String? rawScheduleJson;
  final String? semesterCode;

  const ScheduleCache({
    required this.courses,
    this.rawScheduleJson,
    this.semesterCode,
  });
}

class ScheduleRepository {
  ScheduleRepository({AppStorage? storage})
    : _storage = storage ?? AppStorage.instance;

  final AppStorage _storage;

  Future<ScheduleCache> loadCache({String? semesterCode}) async {
    if (semesterCode != null && semesterCode.isNotEmpty) {
      final archive = await _storage.loadSemesterArchive(semesterCode);
      return ScheduleCache(
        courses: archive?.courses ?? const <Course>[],
        rawScheduleJson: archive?.rawScheduleJson,
        semesterCode: semesterCode,
      );
    }

    final courses = await _storage.loadCourses();
    final rawScheduleJson = await _storage.loadRawScheduleJson();
    final activeSemesterCode = await _storage.loadActiveSemesterCode();
    return ScheduleCache(
      courses: courses,
      rawScheduleJson: rawScheduleJson,
      semesterCode: activeSemesterCode,
    );
  }

  Future<List<Course>> loadCourses() => _storage.loadCourses();

  Future<void> saveCourses(List<Course> courses) =>
      _storage.saveCourses(courses);

  Future<String?> loadRawScheduleJson() => _storage.loadRawScheduleJson();

  Future<void> saveRawScheduleJson(String json) =>
      _storage.saveRawScheduleJson(json);

  Future<String?> loadActiveSemesterCode() => _storage.loadActiveSemesterCode();

  Future<void> saveActiveSemesterCode(String semester) =>
      _storage.saveActiveSemesterCode(semester);

  Future<List<String>> loadAvailableSemesterCodes() =>
      _storage.loadAvailableSemesterCodes();

  Future<List<SemesterOption>> loadKnownSemesterOptions() =>
      _storage.loadKnownSemesterOptions();

  Future<void> saveKnownSemesterOptions(List<SemesterOption> options) =>
      _storage.saveKnownSemesterOptions(options);

  Future<List<SemesterOption>> loadSemesterCatalog() =>
      _storage.loadSemesterCatalog();

  Future<void> saveSemesterCatalog(List<SemesterOption> options) =>
      _storage.saveSemesterCatalog(options);

  Future<bool> loadHasSyncedAtLeastOneSemester() =>
      _storage.loadHasSyncedAtLeastOneSemester();

  Future<bool> loadSyncWritingLock() => _storage.loadSyncWritingLock();

  Future<void> saveHasSyncedAtLeastOneSemester(bool value) =>
      _storage.saveHasSyncedAtLeastOneSemester(value);

  Future<void> saveImportedSchedule({
    required String rawScheduleJson,
    required String semesterCode,
    required List<Course> courses,
  }) async {
    await _storage.saveSemesterArchive(
      semesterCode: semesterCode,
      rawScheduleJson: rawScheduleJson,
      courses: courses,
      makeActive: true,
    );
  }

  Future<void> saveSemesterSchedule({
    required String semesterCode,
    String? rawScheduleJson,
    required List<Course> courses,
    bool makeActive = true,
  }) {
    return _storage.saveSemesterArchive(
      semesterCode: semesterCode,
      rawScheduleJson: rawScheduleJson,
      courses: courses,
      makeActive: makeActive,
    );
  }

  Future<void> createEmptySemester({
    required String semesterCode,
    bool makeActive = true,
  }) {
    return _storage.saveSemesterArchive(
      semesterCode: semesterCode,
      courses: const <Course>[],
      makeActive: makeActive,
    );
  }

  Future<void> deleteSemester(String semesterCode) {
    return _storage.deleteSemesterArchive(semesterCode);
  }
}

class SchedulePreferencesRepository {
  SchedulePreferencesRepository({AppStorage? storage})
    : _storage = storage ?? AppStorage.instance;

  final AppStorage _storage;

  Future<ScheduleViewPreferences> load() =>
      _storage.loadScheduleViewPreferences();

  Future<void> save({
    required int displayDays,
    required bool showNonCurrentWeek,
  }) {
    return _storage.saveScheduleViewPreferences(
      displayDays: displayDays,
      showNonCurrentWeek: showNonCurrentWeek,
    );
  }
}

class SchoolTimeRepository {
  SchoolTimeRepository({AppStorage? storage})
    : _storage = storage ?? AppStorage.instance;

  final AppStorage _storage;

  Future<SchoolTimeConfig> load() => _storage.loadSchoolTimeConfig();

  Future<void> save(SchoolTimeConfig config) =>
      _storage.saveSchoolTimeConfig(config);

  Future<SchoolTimeGeneratorSettings> loadGeneratorSettings() =>
      _storage.loadSchoolTimeGeneratorSettings();

  Future<void> saveGeneratorSettings(SchoolTimeGeneratorSettings settings) =>
      _storage.saveSchoolTimeGeneratorSettings(settings);

  Future<void> reset() => _storage.clearSchoolTimeConfig();
}

class SyncRepository {
  SyncRepository({AppStorage? storage})
    : _storage = storage ?? AppStorage.instance;

  final AppStorage _storage;

  Future<StoredAutoSyncRecord> loadRecord({String? semesterCode}) =>
      _storage.loadAutoSyncRecord(semesterCode: semesterCode);

  Future<void> saveFrequency(String frequency, {int? customIntervalMinutes}) =>
      _storage.saveAutoSyncSettings(
        frequency,
        customIntervalMinutes: customIntervalMinutes,
      );

  Future<void> saveStatus({
    String? state,
    String? message,
    String? source,
    String? diffSummary,
    String? error,
    String? cookieSnapshot,
    String? semesterCode,
    bool clearError = false,
    bool clearDiffSummary = false,
    DateTime? lastFetchTime,
    DateTime? lastAttemptTime,
    DateTime? nextSyncTime,
    bool clearNextSyncTime = false,
  }) {
    return _storage.saveAutoSyncRecord(
      state: state,
      message: message,
      source: source,
      diffSummary: diffSummary,
      error: error,
      cookieSnapshot: cookieSnapshot,
      semesterCode: semesterCode,
      clearError: clearError,
      clearDiffSummary: clearDiffSummary,
      lastFetchTime: lastFetchTime,
      lastAttemptTime: lastAttemptTime,
      nextSyncTime: nextSyncTime,
      clearNextSyncTime: clearNextSyncTime,
    );
  }

  Future<void> saveSemesterSyncRecord({
    required String semesterCode,
    required int count,
    required DateTime lastSyncTime,
  }) {
    return _storage.saveSemesterSyncRecord(
      semesterCode: semesterCode,
      count: count,
      lastSyncTime: lastSyncTime,
    );
  }

  Future<SemesterSyncRecord?> loadSemesterSyncRecord(String semesterCode) =>
      _storage.loadSemesterSyncRecord(semesterCode);

  Future<void> saveCookieSnapshot(String cookie) =>
      _storage.saveCookieSnapshot(cookie);

  Future<String?> loadCookieSnapshot() => _storage.loadCookieSnapshot();

  Future<void> saveStudentId(String studentId) =>
      _storage.saveStudentId(studentId);

  Future<String?> loadStudentId() => _storage.loadStudentId();

  Future<void> saveLastFetchTime(DateTime time) =>
      _storage.saveLastFetchTime(time);
}

class ReminderRepository {
  ReminderRepository({AppStorage? storage})
    : _storage = storage ?? AppStorage.instance;

  final AppStorage _storage;

  Future<StoredReminderRecord> loadRecord() => _storage.loadReminderRecord();

  Future<void> saveLeadMinutes(int leadMinutes) =>
      _storage.saveReminderLeadMinutes(leadMinutes);

  Future<void> saveState({
    int? scheduledCount,
    DateTime? lastBuildTime,
    bool clearLastBuildTime = false,
    DateTime? horizonEnd,
    bool? exactAlarmEnabled,
    bool clearHorizonEnd = false,
  }) {
    return _storage.saveReminderRecord(
      scheduledCount: scheduledCount,
      lastBuildTime: lastBuildTime,
      clearLastBuildTime: clearLastBuildTime,
      horizonEnd: horizonEnd,
      exactAlarmEnabled: exactAlarmEnabled,
      clearHorizonEnd: clearHorizonEnd,
    );
  }
}

class ClassSilenceRepository {
  Future<ClassSilenceStoredState> loadState() => ClassSilenceStore.load();

  Future<void> saveEnabled(bool enabled) =>
      ClassSilenceStore.saveEnabled(enabled);

  Future<void> saveState({
    int? scheduledCount,
    DateTime? lastBuildTime,
    bool clearLastBuildTime = false,
    DateTime? horizonEnd,
    bool clearHorizonEnd = false,
  }) {
    return ClassSilenceStore.saveScheduleState(
      scheduledCount: scheduledCount,
      lastBuildTime: lastBuildTime,
      clearLastBuildTime: clearLastBuildTime,
      horizonEnd: horizonEnd,
      clearHorizonEnd: clearHorizonEnd,
    );
  }
}

class ScheduleOverrideRepository {
  ScheduleOverrideRepository({AppStorage? storage})
    : _storage = storage ?? AppStorage.instance;

  final AppStorage _storage;

  Future<List<ScheduleOverride>> load(String? semesterCode) {
    return _storage.loadScheduleOverrides(semesterCode: semesterCode);
  }

  Future<void> save({
    required String semesterCode,
    required List<ScheduleOverride> overrides,
  }) {
    return _storage.saveScheduleOverrides(
      overrides,
      semesterCode: semesterCode,
    );
  }
}
