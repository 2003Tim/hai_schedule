import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';

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
