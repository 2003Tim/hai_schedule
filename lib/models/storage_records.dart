import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/models/schedule_override.dart';

class SemesterSyncRecord {
  final int count;
  final DateTime lastSyncTime;

  const SemesterSyncRecord({required this.count, required this.lastSyncTime});

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'count': count,
      'lastSyncTime': lastSyncTime.toIso8601String(),
    };
  }

  factory SemesterSyncRecord.fromJson(Map<String, dynamic> json) {
    final lastSyncTime = DateTime.tryParse(
      json['lastSyncTime']?.toString() ?? '',
    );
    if (lastSyncTime == null) {
      throw const FormatException('lastSyncTime 缺失');
    }
    return SemesterSyncRecord(
      count: (json['count'] as num?)?.toInt() ?? 0,
      lastSyncTime: lastSyncTime.toLocal(),
    );
  }
}

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
  final String? stateSemesterCode;
  final String? cookieSnapshot;
  final String? rawScheduleJson;
  final SemesterSyncRecord? semesterSyncRecord;

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
    this.stateSemesterCode,
    this.cookieSnapshot,
    this.rawScheduleJson,
    this.semesterSyncRecord,
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

class StoredSemesterCatalog {
  final List<SemesterOption> options;

  const StoredSemesterCatalog({required this.options});
}

class StoredScheduleOverrideRecord {
  final List<ScheduleOverride> overrides;

  const StoredScheduleOverrideRecord({required this.overrides});
}
