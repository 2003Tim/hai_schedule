import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_state_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
  });

  test(
    'load waits for sync writing lock before accepting active semester cache',
    () async {
      final repository = ScheduleRepository();
      final loader = ScheduleStateLoader();

      await repository.createEmptySemester(
        semesterCode: '20252',
        makeActive: true,
      );
      await AppStorage.instance.setSyncWritingLock(true);

      final writeFuture = Future<void>.delayed(
        const Duration(milliseconds: 250),
        () async {
          await repository.saveSemesterSchedule(
            semesterCode: '20252',
            courses: <Course>[_sampleCourse()],
            makeActive: true,
          );
          await AppStorage.instance.setSyncWritingLock(false);
        },
      );

      final state = await loader.load();
      await writeFuture;

      expect(state.currentSemesterCode, '20252');
      expect(state.courses, hasLength(1));
      expect(state.courses.single.name, '软件工程');
    },
  );

  test(
    'load returns immediately for a legitimate empty semester without writing lock',
    () async {
      final repository = ScheduleRepository();
      final loader = ScheduleStateLoader();

      await repository.createEmptySemester(
        semesterCode: '20252',
        makeActive: true,
      );

      final stopwatch = Stopwatch()..start();
      final state = await loader.load();
      stopwatch.stop();

      expect(state.currentSemesterCode, '20252');
      expect(state.courses, isEmpty);
      expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 200)));
    },
  );
}

Course _sampleCourse() {
  return Course(
    id: 'course-1',
    code: 'SE001',
    name: '软件工程',
    className: '计科一班',
    teacher: '陈老师',
    college: '计算机科学与技术学院',
    credits: 3,
    totalHours: 48,
    semester: '2025-2026-2',
    slots: <ScheduleSlot>[
      ScheduleSlot(
        courseId: 'course-1',
        courseName: '软件工程',
        teacher: '陈老师',
        weekday: 1,
        startSection: 1,
        endSection: 2,
        location: '教一-101',
        weekRanges: <WeekRange>[WeekRange(start: 1, end: 16)],
      ),
    ],
  );
}
