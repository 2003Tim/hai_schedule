import 'package:timezone/timezone.dart' as tz;

import 'package:hai_schedule/models/class_silence_models.dart';
import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/schedule_override_matcher.dart';
import 'package:hai_schedule/utils/week_calculator.dart';

class ClassSilencePlanner {
  const ClassSilencePlanner._();

  static List<SilenceScheduleEvent> buildEvents({
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
    required WeekCalculator weekCalc,
    required SchoolTimeConfig timeConfig,
    required tz.TZDateTime now,
    required tz.TZDateTime horizonEnd,
    required tz.Location location,
  }) {
    final events = <SilenceScheduleEvent>[];
    final startDate = DateTime(now.year, now.month, now.day);
    final totalDays = horizonEnd.difference(now).inDays + 1;

    for (var offset = 0; offset < totalDays; offset++) {
      final day = startDate.add(Duration(days: offset));
      final week = weekCalc.getWeekNumber(day);
      if (week <= 0 || week > weekCalc.totalWeeks) continue;

      final items = _resolveDaySchedule(
        day: day,
        week: week,
        courses: courses,
        overrides: overrides,
      );

      for (final item in items) {
        final slotTime = timeConfig.getSlotTime(
          item.slot.startSection,
          item.slot.endSection,
        );
        if (slotTime == null) continue;

        final startParts = slotTime.$1.split(':');
        final endParts = slotTime.$2.split(':');
        if (startParts.length != 2 || endParts.length != 2) continue;

        final startHour = int.tryParse(startParts[0]);
        final startMinute = int.tryParse(startParts[1]);
        final endHour = int.tryParse(endParts[0]);
        final endMinute = int.tryParse(endParts[1]);
        if (startHour == null ||
            startMinute == null ||
            endHour == null ||
            endMinute == null) {
          continue;
        }

        final classStart = tz.TZDateTime(
          location,
          day.year,
          day.month,
          day.day,
          startHour,
          startMinute,
        );
        final classEnd = tz.TZDateTime(
          location,
          day.year,
          day.month,
          day.day,
          endHour,
          endMinute,
        );

        if (!classEnd.isAfter(now)) continue;
        if (classStart.isAfter(horizonEnd)) continue;

        final date = formatDate(day);
        events.add(
          SilenceScheduleEvent(
            id:
                '$date-${item.slot.courseId}-${item.slot.startSection}-${item.slot.endSection}',
            courseName: item.slot.courseName,
            date: date,
            startSection: item.slot.startSection,
            endSection: item.slot.endSection,
            startAtMillis: classStart.millisecondsSinceEpoch,
            endAtMillis: classEnd.millisecondsSinceEpoch,
          ),
        );
      }
    }

    events.sort((a, b) => a.startAtMillis.compareTo(b.startAtMillis));
    return events;
  }

  static List<_ResolvedSilenceItem> _resolveDaySchedule({
    required DateTime day,
    required int week,
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
  }) {
    final dateKey = formatDate(day);
    final weekday = day.weekday;
    final dayOverrides =
        overrides
            .where((item) => item.dateKey == dateKey && item.weekday == weekday)
            .toList();

    final items = <_ResolvedSilenceItem>[];

    for (final course in courses) {
      for (final slot in course.slots) {
        if (slot.weekday != weekday || !slot.isActiveInWeek(week)) continue;

        var cancelled = false;
        for (final item in dayOverrides) {
          if (item.type != ScheduleOverrideType.cancel) continue;
          if (item.status == ScheduleOverrideStatus.orphaned) continue;
          if (ScheduleOverrideMatcher.matchesSource(item, slot)) {
            cancelled = true;
            break;
          }
        }
        if (cancelled) continue;

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
            _ResolvedSilenceItem(
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
            ),
          );
          continue;
        }

        items.add(_ResolvedSilenceItem(slot: slot));
      }
    }

    for (final item in dayOverrides.where(
      (value) =>
          value.type == ScheduleOverrideType.add &&
          value.status != ScheduleOverrideStatus.orphaned,
    )) {
      items.add(
        _ResolvedSilenceItem(
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
        ),
      );
    }

    items.sort((a, b) => a.slot.startSection.compareTo(b.slot.startSection));
    return items;
  }

  static String formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _ResolvedSilenceItem {
  final ScheduleSlot slot;

  const _ResolvedSilenceItem({required this.slot});
}
