import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/utils/schedule_override_matcher.dart';
import 'package:hai_schedule/utils/week_calculator.dart';

class ScheduleOverrideValidationResult {
  const ScheduleOverrideValidationResult({
    required this.overrides,
    required this.changed,
  });

  final List<ScheduleOverride> overrides;
  final bool changed;
}

class ScheduleOverrideValidator {
  const ScheduleOverrideValidator._();

  static ScheduleOverrideValidationResult revalidate({
    required List<ScheduleOverride> overrides,
    required List<Course> courses,
    required String semesterCode,
    required WeekCalculator weekCalc,
  }) {
    final updated =
        overrides
            .map(
              (item) => _validateOverride(
                item,
                semesterCode: semesterCode,
                courses: courses,
                weekCalc: weekCalc,
              ),
            )
            .toList();
    return ScheduleOverrideValidationResult(
      overrides: updated,
      changed: !_sameOverrideStates(overrides, updated),
    );
  }

  static ScheduleOverride _validateOverride(
    ScheduleOverride item, {
    required String semesterCode,
    required List<Course> courses,
    required WeekCalculator weekCalc,
  }) {
    if (item.type == ScheduleOverrideType.add) {
      return _copyOverrideWithStatus(
        item,
        semesterCode: semesterCode,
        status: ScheduleOverrideStatus.normal,
      );
    }

    final week = _weekForDateKey(item.dateKey, weekCalc: weekCalc);
    if (week == null) {
      return _copyOverrideWithStatus(
        item,
        semesterCode: semesterCode,
        status: ScheduleOverrideStatus.orphaned,
      );
    }

    final matched = courses.any((course) {
      for (final slot in course.slots) {
        if (slot.weekday != item.weekday) continue;
        if (!slot.isActiveInWeek(week)) continue;

        if (ScheduleOverrideMatcher.matchesSource(item, slot)) {
          final effectiveTeacher =
              slot.teacher.isNotEmpty ? slot.teacher : course.teacher;
          final sourceNameMatches =
              item.sourceCourseName.isEmpty ||
              slot.courseName == item.sourceCourseName;
          final sourceTeacherMatches =
              item.sourceTeacher.isEmpty ||
              effectiveTeacher == item.sourceTeacher;
          final sourceLocationMatches =
              item.sourceLocation.isEmpty ||
              slot.location == item.sourceLocation;
          final sourceSectionMatches =
              (item.sourceStartSection == null ||
                  slot.startSection == item.sourceStartSection) &&
              (item.sourceEndSection == null ||
                  slot.endSection == item.sourceEndSection);

          return sourceNameMatches &&
              sourceTeacherMatches &&
              sourceLocationMatches &&
              sourceSectionMatches;
        }
      }
      return false;
    });

    return _copyOverrideWithStatus(
      item,
      semesterCode: semesterCode,
      status:
          matched
              ? ScheduleOverrideStatus.normal
              : ScheduleOverrideStatus.orphaned,
    );
  }

  static ScheduleOverride _copyOverrideWithStatus(
    ScheduleOverride item, {
    required String semesterCode,
    required ScheduleOverrideStatus status,
  }) {
    return ScheduleOverride(
      id: item.id,
      semesterCode: semesterCode,
      dateKey: item.dateKey,
      weekday: item.weekday,
      startSection: item.startSection,
      endSection: item.endSection,
      type: item.type,
      targetCourseId: item.targetCourseId,
      courseName: item.courseName,
      teacher: item.teacher,
      location: item.location,
      note: item.note,
      status: status,
      sourceCourseName: item.sourceCourseName,
      sourceTeacher: item.sourceTeacher,
      sourceLocation: item.sourceLocation,
      sourceStartSection: item.sourceStartSection,
      sourceEndSection: item.sourceEndSection,
    );
  }

  static int? _weekForDateKey(
    String dateKey, {
    required WeekCalculator weekCalc,
  }) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    final date = DateTime(year, month, day);
    final week = weekCalc.getWeekNumber(date);
    if (week < 1 || week > weekCalc.totalWeeks) return null;
    return week;
  }

  static bool _sameOverrideStates(
    List<ScheduleOverride> left,
    List<ScheduleOverride> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id ||
          left[index].status != right[index].status) {
        return false;
      }
    }
    return true;
  }
}
