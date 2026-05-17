import 'package:hai_schedule/models/auto_sync_models.dart';
import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/utils/auto_sync_course_diff.dart';
import 'package:hai_schedule/utils/auto_sync_text.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/schedule_provider.dart';

class ScheduleSyncApplyResult {
  final int courseCount;
  final String diffSummary;
  final String message;

  const ScheduleSyncApplyResult({
    required this.courseCount,
    required this.diffSummary,
    required this.message,
  });
}

class ScheduleSyncResultService {
  ScheduleSyncResultService({
    SyncRepository? syncRepository,
    ScheduleRepository? scheduleRepository,
  }) : _syncRepository = syncRepository ?? SyncRepository(),
       _scheduleRepository = scheduleRepository ?? ScheduleRepository();

  final SyncRepository _syncRepository;
  final ScheduleRepository _scheduleRepository;

  Future<ScheduleSyncApplyResult> applySuccessfulSync({
    required ScheduleProvider provider,
    required List<Course> courses,
    required String rawScheduleJson,
    required String source,
    String? semesterCode,
  }) async {
    final targetSemester = semesterCode?.trim();
    final previousCourses =
        targetSemester == null || targetSemester.isEmpty
            ? List<Course>.from(provider.courses)
            : List<Course>.from(
              (await _scheduleRepository.loadCache(
                semesterCode: targetSemester,
              )).courses,
            );
    final now = DateTime.now();
    final diffSummary = AutoSyncCourseDiff.buildSummary(
      previousCourses,
      courses,
    );
    final message = AutoSyncText.buildSuccessMessage(
      courses.length,
      diffSummary,
    );

    await provider.setCourses(
      courses,
      semesterCode: semesterCode,
      rawScheduleJson: rawScheduleJson,
    );
    await provider.markHasSyncedAtLeastOneSemester();
    final resolvedSemesterCode =
        targetSemester?.isNotEmpty == true
            ? targetSemester
            : provider.currentSemesterCode;
    if (resolvedSemesterCode != null && resolvedSemesterCode.isNotEmpty) {
      await _syncRepository.saveSemesterSyncRecord(
        semesterCode: resolvedSemesterCode,
        count: courses.length,
        lastSyncTime: now,
      );
    }
    await _syncRepository.saveStatus(
      lastFetchTime: now,
      lastAttemptTime: now,
      state: AutoSyncState.success.value,
      source: source,
      message: message,
      diffSummary: diffSummary,
      semesterCode: resolvedSemesterCode,
      clearError: true,
    );

    return ScheduleSyncApplyResult(
      courseCount: courses.length,
      diffSummary: diffSummary,
      message: message,
    );
  }
}
