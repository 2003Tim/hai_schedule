import 'course.dart';
import 'schedule_override.dart';

class DisplayScheduleSlot {
  const DisplayScheduleSlot({
    required this.slot,
    required this.teacher,
    required this.isActive,
    this.isOverride = false,
    this.overrideType,
    this.sourceOverride,
  });

  final ScheduleSlot slot;
  final String teacher;
  final bool isActive;
  final bool isOverride;
  final ScheduleOverrideType? overrideType;
  final ScheduleOverride? sourceOverride;

  bool get isReferenceOnly => !isActive && overrideType == null;

  bool get canMarkCancel =>
      isActive &&
      overrideType != ScheduleOverrideType.add &&
      overrideType != ScheduleOverrideType.cancel;

  bool get canAdjustOccurrence =>
      !isReferenceOnly && overrideType != ScheduleOverrideType.cancel;
}
