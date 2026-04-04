import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/week_calculator.dart';
import 'package:hai_schedule/services/class_reminder_service.dart';
import 'package:hai_schedule/services/class_silence_service.dart';
import 'package:hai_schedule/services/widget_sync_service.dart';

class ScheduleDerivedOutputCoordinator {
  const ScheduleDerivedOutputCoordinator();

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

    if (forceReminderRebuild) {
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
