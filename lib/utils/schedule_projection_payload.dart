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

    for (final course in courses) {
      for (final slot in course.slots) {
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
      'classTimes':
          timeConfig.classTimes
              .map(
                (t) => <String, dynamic>{
                  'section': t.section,
                  'startTime': t.startTime,
                  'endTime': t.endTime,
                },
              )
              .toList(growable: false),
      'slots': flattenedSlots,
      'overrides':
          overrides
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
                  'color': CourseColors.getColor(item.courseName).toARGB32(),
                },
              )
              .toList(growable: false),
    };
  }

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
