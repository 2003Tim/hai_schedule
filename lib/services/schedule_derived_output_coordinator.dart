import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/week_calculator.dart';
import 'package:hai_schedule/services/class_reminder_service.dart';
import 'package:hai_schedule/services/class_silence_service.dart';
import 'package:hai_schedule/services/widget_sync_service.dart';

/// 协调课表派生输出（桌面小组件、课前提醒、自动静音）的同步。
///
/// 调用方在课程数据/时间配置/override 写入后调用 [sync]，传入
/// [forceReminderRebuild]=true 表达"调用方认为可能需要重建"的意图。
/// 但 Coordinator 内部会用 [_DerivedOutputFingerprint] 对比上一次的输入，
/// 如果指纹完全未变，则会自动降级为 [ClassReminderService.ensureCoverage] /
/// [ClassSilenceService.ensureCoverage]，避免因偏好设置等无关变更触发整轮
/// 通知重建。
class ScheduleDerivedOutputCoordinator {
  ScheduleDerivedOutputCoordinator();

  _DerivedOutputFingerprint? _lastFingerprint;

  Future<void> sync({
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
    bool forceReminderRebuild = false,
  }) async {
    await WidgetSyncService.syncSchedule(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
    );

    final fingerprint = _DerivedOutputFingerprint.from(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
    );
    final fingerprintChanged = _lastFingerprint != fingerprint;
    _lastFingerprint = fingerprint;

    final shouldRebuild = forceReminderRebuild && fingerprintChanged;

    if (shouldRebuild) {
      await ClassReminderService.rebuildForSchedule(
        courses: courses,
        overrides: overrides,
        weekCalc: weekCalc,
        timeConfig: timeConfig,
      );
      await ClassSilenceService.rebuildForSchedule(
        courses: courses,
        overrides: overrides,
        weekCalc: weekCalc,
        timeConfig: timeConfig,
      );
      return;
    }

    await ClassReminderService.ensureCoverage(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
    );
    await ClassSilenceService.ensureCoverage(
      courses: courses,
      overrides: overrides,
      weekCalc: weekCalc,
      timeConfig: timeConfig,
    );
  }
}

class _DerivedOutputFingerprint {
  const _DerivedOutputFingerprint({
    required this.coursesHash,
    required this.overridesHash,
    required this.semesterStartEpochDays,
    required this.totalWeeks,
    required this.timeConfigHash,
  });

  factory _DerivedOutputFingerprint.from({
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
  }) {
    return _DerivedOutputFingerprint(
      coursesHash: _hashCourses(courses),
      overridesHash: _hashOverrides(overrides),
      semesterStartEpochDays:
          weekCalc.semesterStart.toUtc().millisecondsSinceEpoch ~/
              const Duration(days: 1).inMilliseconds,
      totalWeeks: weekCalc.totalWeeks,
      timeConfigHash: _hashTimeConfig(timeConfig),
    );
  }

  final int coursesHash;
  final int overridesHash;
  final int semesterStartEpochDays;
  final int totalWeeks;
  final int timeConfigHash;

  @override
  bool operator ==(Object other) {
    return other is _DerivedOutputFingerprint &&
        other.coursesHash == coursesHash &&
        other.overridesHash == overridesHash &&
        other.semesterStartEpochDays == semesterStartEpochDays &&
        other.totalWeeks == totalWeeks &&
        other.timeConfigHash == timeConfigHash;
  }

  @override
  int get hashCode => Object.hash(
    coursesHash,
    overridesHash,
    semesterStartEpochDays,
    totalWeeks,
    timeConfigHash,
  );

  static int _hashCourses(List<Course> courses) {
    if (courses.isEmpty) return 0;
    var hash = 17;
    for (final course in courses) {
      hash = _combine(hash, course.id.hashCode);
      hash = _combine(hash, course.name.hashCode);
      hash = _combine(hash, course.teacher.hashCode);
      for (final slot in course.slots) {
        hash = _combine(hash, slot.weekday.hashCode);
        hash = _combine(hash, slot.startSection.hashCode);
        hash = _combine(hash, slot.endSection.hashCode);
        hash = _combine(hash, slot.location.hashCode);
        for (final range in slot.weekRanges) {
          hash = _combine(hash, range.start.hashCode);
          hash = _combine(hash, range.end.hashCode);
          hash = _combine(hash, range.type.index);
        }
      }
    }
    return hash;
  }

  static int _hashOverrides(List<ScheduleOverride> overrides) {
    if (overrides.isEmpty) return 0;
    var hash = 17;
    for (final item in overrides) {
      hash = _combine(hash, item.id.hashCode);
      hash = _combine(hash, item.dateKey.hashCode);
      hash = _combine(hash, item.weekday.hashCode);
      hash = _combine(hash, item.startSection.hashCode);
      hash = _combine(hash, item.endSection.hashCode);
      hash = _combine(hash, item.type.index);
      hash = _combine(hash, item.status.index);
      hash = _combine(hash, item.courseName.hashCode);
      hash = _combine(hash, item.teacher.hashCode);
      hash = _combine(hash, item.location.hashCode);
    }
    return hash;
  }

  static int _hashTimeConfig(SchoolTimeConfig config) {
    var hash = 17;
    hash = _combine(hash, config.totalSections);
    for (final section in config.classTimes) {
      hash = _combine(hash, section.startMinutes.hashCode);
      hash = _combine(hash, section.endMinutes.hashCode);
    }
    return hash;
  }

  static int _combine(int hash, int value) {
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }
}
