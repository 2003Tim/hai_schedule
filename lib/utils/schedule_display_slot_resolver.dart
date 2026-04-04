import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/display_schedule_slot.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/utils/schedule_override_matcher.dart';
import 'package:hai_schedule/utils/week_calculator.dart';

class ScheduleDisplaySlotResolver {
  const ScheduleDisplaySlotResolver._();

  static DisplayScheduleSlot? resolve({
    required int week,
    required int weekday,
    required int section,
    required List<Course> courses,
    required List<ScheduleOverride> overrides,
    required WeekCalculator weekCalc,
    required bool showNonCurrentWeek,
  }) {
    final date = weekCalc.getDate(week, weekday);
    final dateKey = dateKeyFor(date);
    final dayOverrides =
        overrides
            .where((item) => item.dateKey == dateKey && item.weekday == weekday)
            .toList();

    final displayOverride = _findDisplayOverride(dayOverrides, section);
    if (displayOverride != null) {
      final sourceMatch =
          displayOverride.type == ScheduleOverrideType.modify
              ? _resolveOverrideSourceSlot(
                week: week,
                weekday: weekday,
                override: displayOverride,
                courses: courses,
              )
              : null;
      return DisplayScheduleSlot(
        slot: _slotFromOverride(displayOverride, fallback: sourceMatch?.slot),
        teacher:
            displayOverride.teacher.isNotEmpty
                ? displayOverride.teacher
                : sourceMatch?.teacher ?? '',
        isActive: true,
        isOverride: true,
        overrideType: displayOverride.type,
        sourceOverride: displayOverride,
      );
    }

    for (final course in courses) {
      for (final slot in course.slots) {
        if (slot.weekday != weekday ||
            slot.startSection > section ||
            slot.endSection < section) {
          continue;
        }

        if (slot.isActiveInWeek(week)) {
          final cancelOverride = _findTargetedOverride(
            dayOverrides,
            slot,
            ScheduleOverrideType.cancel,
          );
          if (cancelOverride != null) {
            return DisplayScheduleSlot(
              slot: slot,
              teacher: course.teacher,
              isActive: false,
              isOverride: true,
              overrideType: cancelOverride.type,
              sourceOverride: cancelOverride,
            );
          }

          final modifyOverride = _findTargetedOverride(
            dayOverrides,
            slot,
            ScheduleOverrideType.modify,
          );
          if (modifyOverride != null) {
            // Modified slots are rendered from their target sections above.
            continue;
          }

          return DisplayScheduleSlot(
            slot: slot,
            teacher: course.teacher,
            isActive: true,
          );
        }
      }
    }

    if (!showNonCurrentWeek) return null;

    for (final course in courses) {
      for (final slot in course.slots) {
        if (slot.weekday == weekday &&
            slot.startSection <= section &&
            slot.endSection >= section &&
            !slot.isActiveInWeek(week) &&
            slot.getAllActiveWeeks().isNotEmpty) {
          return DisplayScheduleSlot(
            slot: slot,
            teacher: course.teacher,
            isActive: false,
          );
        }
      }
    }

    return null;
  }

  static String teacherForSlot({
    required List<Course> courses,
    required ScheduleSlot slot,
  }) {
    for (final course in courses) {
      if (course.id == slot.courseId) {
        return course.teacher;
      }
    }
    return '';
  }

  static ScheduleOverride? overrideForDateSlot({
    required DateTime date,
    required int weekday,
    required int section,
    required List<ScheduleOverride> overrides,
  }) {
    final dateKey = dateKeyFor(date);
    for (final item in overrides) {
      if (item.dateKey == dateKey &&
          item.weekday == weekday &&
          item.coversSection(section)) {
        return item;
      }
    }
    return null;
  }

  static String dateKeyFor(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '${localDate.year}-$month-$day';
  }

  static ScheduleOverride? _findDisplayOverride(
    List<ScheduleOverride> overrides,
    int section,
  ) {
    for (final item in overrides) {
      if (item.status == ScheduleOverrideStatus.orphaned) continue;
      if ((item.type == ScheduleOverrideType.add ||
              item.type == ScheduleOverrideType.modify) &&
          item.startSection <= section &&
          item.endSection >= section) {
        return item;
      }
    }
    return null;
  }

  static ScheduleOverride? _findTargetedOverride(
    List<ScheduleOverride> overrides,
    ScheduleSlot slot,
    ScheduleOverrideType type,
  ) {
    for (final item in overrides) {
      if (item.type != type) continue;
      if (item.status == ScheduleOverrideStatus.orphaned) continue;
      if (ScheduleOverrideMatcher.matchesSource(item, slot)) {
        return item;
      }
    }
    return null;
  }

  static _ResolvedOverrideSource? _resolveOverrideSourceSlot({
    required int week,
    required int weekday,
    required ScheduleOverride override,
    required List<Course> courses,
  }) {
    for (final course in courses) {
      for (final slot in course.slots) {
        if (slot.weekday != weekday || !slot.isActiveInWeek(week)) continue;
        if (!ScheduleOverrideMatcher.matchesSource(override, slot)) continue;
        return _ResolvedOverrideSource(slot: slot, teacher: course.teacher);
      }
    }
    return null;
  }

  static ScheduleSlot _slotFromOverride(
    ScheduleOverride override, {
    ScheduleSlot? fallback,
  }) {
    final source = fallback;
    return ScheduleSlot(
      courseId: source?.courseId ?? override.id,
      courseName:
          override.courseName.isNotEmpty
              ? override.courseName
              : source?.courseName ?? '临时课程',
      teacher:
          override.teacher.isNotEmpty
              ? override.teacher
              : source?.teacher ?? '',
      weekday: override.weekday,
      startSection: override.startSection,
      endSection: override.endSection,
      location:
          override.location.isNotEmpty
              ? override.location
              : source?.location ?? '',
      weekRanges: source?.weekRanges ?? const <WeekRange>[],
    );
  }
}

class _ResolvedOverrideSource {
  const _ResolvedOverrideSource({required this.slot, required this.teacher});

  final ScheduleSlot slot;
  final String teacher;
}
