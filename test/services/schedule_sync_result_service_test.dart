import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/schedule_sync_result_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const homeWidgetChannel = MethodChannel('es.antonborri.home_widget');
  const autoSyncChannel = MethodChannel('hai_schedule/auto_sync');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          if (call.method == 'pendingNotificationRequests') {
            return <Object?>[];
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, (call) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppStorage.instance.resetForTesting();
  });

  test(
    'compares sync diff against target semester archive instead of active semester',
    () async {
      final provider = ScheduleProvider();
      final repository = ScheduleRepository();
      final service = ScheduleSyncResultService(scheduleRepository: repository);

      await provider.setCourses([
        _buildCourse('fall-1', '大学英语', '教一-101'),
      ], semesterCode: '20251');
      await repository.saveSemesterSchedule(
        semesterCode: '20252',
        rawScheduleJson: '{"semester":"20252-old"}',
        courses: [_buildCourse('spring-1', '大学物理', '教二-201')],
        makeActive: false,
      );

      final result = await service.applySuccessfulSync(
        provider: provider,
        courses: [_buildCourse('spring-1', '大学物理', '教三-305')],
        semesterCode: '20252',
        rawScheduleJson: '{"semester":"20252-new"}',
        source: 'test',
      );

      expect(result.diffSummary, '调整 1 门');
      expect(provider.currentSemesterCode, '20252');
      expect(provider.courses.single.name, '大学物理');
      expect(provider.courses.single.slots.single.location, '教三-305');
    },
  );
}

Course _buildCourse(String id, String name, String location) {
  return Course(
    id: id,
    code: id.toUpperCase(),
    name: name,
    className: '测试班级',
    teacher: '测试老师',
    college: '测试学院',
    credits: 2,
    totalHours: 32,
    semester: '2025-2026',
    slots: [
      ScheduleSlot(
        courseId: id,
        courseName: name,
        weekday: 1,
        startSection: 1,
        endSection: 2,
        location: location,
        weekRanges: [WeekRange(start: 1, end: 16)],
      ),
    ],
  );
}
