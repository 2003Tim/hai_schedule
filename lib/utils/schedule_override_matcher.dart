import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';

class ScheduleOverrideMatcher {
  ScheduleOverrideMatcher._();

  static bool matchesSource(ScheduleOverride item, ScheduleSlot slot) {
    final targetCourseId = item.targetCourseId;
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
      return slot.startSection == sourceStart && slot.endSection == sourceEnd;
    }

    if (targetCourseId != null && targetCourseId.isNotEmpty) {
      if (item.type == ScheduleOverrideType.modify) {
        return true;
      }
      return slot.startSection == item.startSection &&
          slot.endSection == item.endSection;
    }

    return slot.startSection == item.startSection &&
        slot.endSection == item.endSection;
  }
}
