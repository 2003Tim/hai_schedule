import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/constants.dart';
import 'package:hai_schedule/utils/week_calculator.dart';

class ScheduleProjectionPayload {
  const ScheduleProjectionPayload._();

  static const int schemaVersion = 2;

  static Map<String, dynamic> build({
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
    DateTime? generatedAt,
  }) {
    final flattenedSlots = <Map<String, dynamic>>[];
    final sourceSlots = <ScheduleSlot>[];

    for (final course in courses) {
      for (final slot in course.slots) {
        sourceSlots.add(slot);
        flattenedSlots.add({
          'courseId': slot.courseId,
          'courseName': slot.courseName,
          'teacher': slot.teacher.isNotEmpty ? slot.teacher : course.teacher,
          'location': slot.location,
          'weekday': slot.weekday,
          'startSection': slot.startSection,
          'endSection': slot.endSection,
          'activeWeeks': slot.getAllActiveWeeks(),
          'color': CourseColors.getColor(slot.courseName).toARGB32(),
        });
      }
    }

    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'generatedAt': (generatedAt ?? DateTime.now()).toIso8601String(),
      'semesterStart': _dateOnly(weekCalc.semesterStart),
      'totalWeeks': weekCalc.totalWeeks,
      'classTimes': timeConfig.classTimes
          .map(
            (t) => <String, dynamic>{
              'section': t.section,
              'startTime': t.startTime,
              'endTime': t.endTime,
            },
          )
          .toList(growable: false),
      'slots': flattenedSlots,
      'overrides': overrides
          .map(
            (item) => <String, dynamic>{
              'id': item.id,
              'semesterCode': item.semesterCode,
              'dateKey': item.dateKey,
              'weekday': item.weekday,
              'startSection': item.startSection,
              'endSection': item.endSection,
              'type': item.type.name,
              'targetCourseId': item.targetCourseId,
              'courseName': item.courseName,
              'teacher': item.teacher,
              'location': item.location,
              'note': item.note,
              'status': item.status.name,
              'sourceCourseName': item.sourceCourseName,
              'sourceTeacher': item.sourceTeacher,
              'sourceLocation': item.sourceLocation,
              'sourceStartSection': item.sourceStartSection,
              'sourceEndSection': item.sourceEndSection,
              'activeWeeks': _overrideActiveWeeks(
                item,
                weekCalc: weekCalc,
                sourceSlots: sourceSlots,
              ),
              'color': CourseColors.getColor(item.courseName).toARGB32(),
            },
          )
          .toList(growable: false),
    };
  }

  static List<int> _overrideActiveWeeks(
    ScheduleOverride item, {
    required WeekCalculator weekCalc,
    required List<ScheduleSlot> sourceSlots,
  }) {
    for (final slot in sourceSlots) {
      if (slot.weekday != item.weekday) continue;
      if (!_matchesSource(item, slot)) continue;
      return slot.getAllActiveWeeks();
    }

    final date = _parseDateKey(item.dateKey);
    if (date == null) return const <int>[];

    final week = weekCalc.getWeekNumber(date);
    if (week < 1 || week > weekCalc.totalWeeks) {
      return const <int>[];
    }
    return <int>[week];
  }

  static bool _matchesSource(ScheduleOverride item, ScheduleSlot slot) {
    final targetCourseId = item.targetCourseId?.trim();
    if (targetCourseId != null &&
        targetCourseId.isNotEmpty &&
        targetCourseId != slot.courseId) {
      return false;
    }

    final hasExplicitSourceSections =
        item.sourceStartSection != null || item.sourceEndSection != null;
    if (hasExplicitSourceSections) {
      final sourceStart = item.sourceStartSection ?? item.startSection;
      final sourceEnd = item.sourceEndSection ?? item.endSection;
      return sourceStart == slot.startSection && sourceEnd == slot.endSection;
    }

    if (targetCourseId != null && targetCourseId.isNotEmpty) {
      return item.type == ScheduleOverrideType.modify ||
          (slot.startSection == item.startSection &&
              slot.endSection == item.endSection);
    }

    return slot.startSection == item.startSection &&
        slot.endSection == item.endSection;
  }

  static DateTime? _parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
