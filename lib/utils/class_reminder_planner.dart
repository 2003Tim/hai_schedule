import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../models/reminder_models.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import 'schedule_override_matcher.dart';
import 'week_calculator.dart';

class ReminderOccurrence {
  final int notificationId;
  final String title;
  final String body;
  final tz.TZDateTime remindAt;
  final Map<String, dynamic> payload;

  const ReminderOccurrence({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.remindAt,
    required this.payload,
  });
}

class ClassReminderPlanner {
  const ClassReminderPlanner._();

  static List<ReminderOccurrence> buildOccurrences({
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
    required int leadMinutes,
    required tz.TZDateTime now,
    required tz.TZDateTime horizonEnd,
    required tz.Location location,
    required String payloadType,
  }) {
    final occurrences = <ReminderOccurrence>[];
    final startDate = DateTime(now.year, now.month, now.day);
    final totalDays = horizonEnd.difference(now).inDays + 1;

    for (var offset = 0; offset < totalDays; offset++) {
      final day = startDate.add(Duration(days: offset));
      final week = weekCalc.getWeekNumber(day);
      if (week <= 0 || week > weekCalc.totalWeeks) continue;

      final dayItems = _resolveDaySchedule(
        day: day,
        week: week,
        courses: courses,
        overrides: overrides,
      );

      for (final item in dayItems) {
        final slotTime = timeConfig.getSlotTime(
          item.slot.startSection,
          item.slot.endSection,
        );
        if (slotTime == null) continue;

        final startParts = slotTime.$1.split(':');
        if (startParts.length != 2) continue;

        final startHour = int.tryParse(startParts[0]);
        final startMinute = int.tryParse(startParts[1]);
        if (startHour == null || startMinute == null) continue;

        final classStart = tz.TZDateTime(
          location,
          day.year,
          day.month,
          day.day,
          startHour,
          startMinute,
        );
        final remindAt = classStart.subtract(Duration(minutes: leadMinutes));

        if (!remindAt.isAfter(now)) continue;
        if (remindAt.isAfter(horizonEnd)) continue;

        final range = '${slotTime.$1}-${slotTime.$2}';
        occurrences.add(
          ReminderOccurrence(
            notificationId: _notificationIdFor(
              courseId: item.slot.courseId,
              date: day,
              startSection: item.slot.startSection,
              endSection: item.slot.endSection,
            ),
            title: '$leadMinutes 分钟后上课',
            body: [
              item.slot.courseName,
              range,
              if (item.slot.location.trim().isNotEmpty)
                item.slot.location.trim(),
            ].join(' · '),
            remindAt: remindAt,
            payload: {
              'type': payloadType,
              'courseId': item.slot.courseId,
              'courseName': item.slot.courseName,
              'teacher': item.teacher,
              'location': item.slot.location,
              'weekday': item.slot.weekday,
              'week': week,
              'date': _formatDate(day),
              'startSection': item.slot.startSection,
              'endSection': item.slot.endSection,
              'startTime': slotTime.$1,
              'endTime': slotTime.$2,
              'leadMinutes': leadMinutes,
            },
          ),
        );
      }
    }

    occurrences.sort((a, b) => a.remindAt.compareTo(b.remindAt));
    return occurrences;
  }

  static ReminderPreviewItem previewItemFromOccurrence(
    ReminderOccurrence occurrence,
  ) {
    final payload = occurrence.payload;
    final startTime = payload['startTime']?.toString() ?? '';
    final endTime = payload['endTime']?.toString() ?? '';
    final timeRange =
        startTime.isEmpty || endTime.isEmpty ? '' : '$startTime - $endTime';
    return ReminderPreviewItem(
      courseName: payload['courseName']?.toString() ?? occurrence.title,
      location: payload['location']?.toString() ?? '',
      timeRange: timeRange,
      dateLabel: payload['date']?.toString() ?? '',
      remindAt: occurrence.remindAt.toLocal(),
      leadMinutes: payload['leadMinutes'] as int? ?? 0,
    );
  }

  static List<_ResolvedReminderItem> _resolveDaySchedule({
    required DateTime day,
    required int week,
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
  }) {
    final dateKey = _formatDate(day);
    final weekday = day.weekday;
    final dayOverrides =
        overrides
            .where((item) => item.dateKey == dateKey && item.weekday == weekday)
            .toList();

    final items = <_ResolvedReminderItem>[];

    for (final course in courses) {
      for (final slot in course.slots) {
        if (slot.weekday != weekday || !slot.isActiveInWeek(week)) {
          continue;
        }

        var cancelled = false;
        for (final item in dayOverrides) {
          if (item.type != ScheduleOverrideType.cancel) continue;
          if (item.status == ScheduleOverrideStatus.orphaned) continue;
          if (ScheduleOverrideMatcher.matchesSource(item, slot)) {
            cancelled = true;
            break;
          }
        }
        if (cancelled) {
          continue;
        }

        ScheduleOverride? modifyOverride;
        for (final item in dayOverrides) {
          if (item.type != ScheduleOverrideType.modify) continue;
          if (item.status == ScheduleOverrideStatus.orphaned) continue;
          if (ScheduleOverrideMatcher.matchesSource(item, slot)) {
            modifyOverride = item;
            break;
          }
        }

        if (modifyOverride != null) {
          items.add(
            _ResolvedReminderItem(
              slot: ScheduleSlot(
                courseId: slot.courseId,
                courseName:
                    modifyOverride.courseName.isNotEmpty
                        ? modifyOverride.courseName
                        : slot.courseName,
                teacher:
                    modifyOverride.teacher.isNotEmpty
                        ? modifyOverride.teacher
                        : slot.teacher,
                weekday: weekday,
                startSection: modifyOverride.startSection,
                endSection: modifyOverride.endSection,
                location:
                    modifyOverride.location.isNotEmpty
                        ? modifyOverride.location
                        : slot.location,
                weekRanges: slot.weekRanges,
              ),
              teacher:
                  modifyOverride.teacher.isNotEmpty
                      ? modifyOverride.teacher
                      : course.teacher,
            ),
          );
          continue;
        }

        items.add(_ResolvedReminderItem(slot: slot, teacher: course.teacher));
      }
    }

    for (final item in dayOverrides.where(
      (value) =>
          value.type == ScheduleOverrideType.add &&
          value.status != ScheduleOverrideStatus.orphaned,
    )) {
      items.add(
        _ResolvedReminderItem(
          slot: ScheduleSlot(
            courseId: item.id,
            courseName: item.courseName.isNotEmpty ? item.courseName : '临时课程',
            teacher: item.teacher,
            weekday: weekday,
            startSection: item.startSection,
            endSection: item.endSection,
            location: item.location,
            weekRanges: const <WeekRange>[],
          ),
          teacher: item.teacher,
        ),
      );
    }

    items.sort((a, b) => a.slot.startSection.compareTo(b.slot.startSection));
    return items;
  }

  static int _notificationIdFor({
    required String courseId,
    required DateTime date,
    required int startSection,
    required int endSection,
  }) {
    final raw = Object.hash(
      courseId,
      date.year,
      date.month,
      date.day,
      startSection,
      endSection,
    );
    return raw.abs() % 2147480000;
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _ResolvedReminderItem {
  final ScheduleSlot slot;
  final String teacher;

  const _ResolvedReminderItem({required this.slot, required this.teacher});
}
