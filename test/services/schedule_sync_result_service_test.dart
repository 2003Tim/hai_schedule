import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/schedule_sync_result_service.dart';

import '../test_helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const homeWidgetChannel = MethodChannel('es.antonborri.home_widget');
  const autoSyncChannel = MethodChannel('hai_schedule/auto_sync');
  const nativeCredentialsChannel = MethodChannel(
    'hai_schedule/native_credentials',
  );

  setUpAll(() {
    SecureStorageMock.install();
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          nativeCredentialsChannel,
          (call) async => null,
        );
  });

  tearDownAll(() {
    SecureStorageMock.uninstall();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeCredentialsChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
    SecureStorageMock.clear();
  });

  test(
    'applySuccessfulSync diffs against the target semester archive',
    () async {
      final provider = ScheduleProvider();
      await provider.ready;

      await provider.setCourses(
        [_course(code: 'ACTIVE', name: '当前学期课程', location: 'A-101')],
        semesterCode: '20251',
        rawScheduleJson: jsonEncode({'semester': '20251'}),
      );
      await AppStorage.instance.saveSemesterArchive(
        semesterCode: '20252',
        rawScheduleJson: jsonEncode({'semester': '20252'}),
        courses: [_course(code: 'MATH001', name: '高等数学', location: 'B-201')],
      );

      final result = await ScheduleSyncResultService().applySuccessfulSync(
        provider: provider,
        courses: [_course(code: 'MATH001', name: '高等数学', location: 'B-202')],
        rawScheduleJson: jsonEncode({'semester': '20252', 'updated': true}),
        source: 'login_fetch',
        semesterCode: '20252',
      );

      expect(result.diffSummary, '调整 1 门');
    },
  );
}

Course _course({
  required String code,
  required String name,
  required String location,
}) {
  return Course(
    id: code,
    code: code,
    name: name,
    className: '测试班',
    teacher: '张老师',
    college: '理学院',
    credits: 2,
    totalHours: 32,
    semester: '2025-2026学年 第二学期',
    slots: [
      ScheduleSlot(
        courseId: code,
        courseName: name,
        weekday: DateTime.monday,
        startSection: 1,
        endSection: 2,
        location: location,
        weekRanges: [WeekRange(start: 1, end: 16)],
      ),
    ],
  );
}
