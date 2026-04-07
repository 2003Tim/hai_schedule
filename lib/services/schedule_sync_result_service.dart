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
    final targetSemesterCode = semesterCode ?? provider.currentSemesterCode;
    final previousCourses = await _loadPreviousCourses(
      provider,
      semesterCode: targetSemesterCode,
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
    await _syncRepository.saveStatus(
      lastFetchTime: now,
      lastAttemptTime: now,
      state: AutoSyncState.success.value,
      source: source,
      message: message,
      diffSummary: diffSummary,
      clearError: true,
    );

    return ScheduleSyncApplyResult(
      courseCount: courses.length,
      diffSummary: diffSummary,
      message: message,
    );
  }

  Future<List<Course>> _loadPreviousCourses(
    ScheduleProvider provider, {
    required String? semesterCode,
  }) async {
    if (semesterCode == null || semesterCode == provider.currentSemesterCode) {
      return List<Course>.from(provider.courses);
    }

    final cache = await _scheduleRepository.loadCache(
      semesterCode: semesterCode,
    );
    return List<Course>.from(cache.courses);
  }
}
