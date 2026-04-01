import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';

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

  group('ScheduleProvider override validation', () {
    test(
      'cancel override stays active when teacher comes from course',
      () async {
        final provider = ScheduleProvider();
        final course = _buildCourse(teacher: '张老师', slotTeacher: '');

        await provider.setCourses([course], semesterCode: '20252');
        final date = provider.getDateForSlot(1, 1);

        await provider.upsertOverride(
          ScheduleOverride(
            id: 'override-cancel',
            semesterCode: '20252',
            dateKey: _dateKey(date),
            weekday: 1,
            startSection: 1,
            endSection: 2,
            type: ScheduleOverrideType.cancel,
            targetCourseId: 'course-1',
            courseName: '高等数学',
            teacher: '张老师',
            location: '教一-101',
            sourceCourseName: '高等数学',
            sourceTeacher: '张老师',
            sourceLocation: '教一-101',
            sourceStartSection: 1,
            sourceEndSection: 2,
          ),
        );

        expect(provider.overrides.single.status, ScheduleOverrideStatus.normal);
        final display = provider.getDisplaySlotAt(1, 1, 1);
        expect(display, isNotNull);
        expect(display!.isActive, isFalse);
        expect(display.overrideType, ScheduleOverrideType.cancel);
      },
    );

    test(
      'modify override becomes orphaned after source course changes',
      () async {
        final provider = ScheduleProvider();
        await provider.setCourses([
          _buildCourse(teacher: '张老师', slotTeacher: ''),
        ], semesterCode: '20252');
        final date = provider.getDateForSlot(1, 1);

        await provider.upsertOverride(
          ScheduleOverride(
            id: 'override-modify',
            semesterCode: '20252',
            dateKey: _dateKey(date),
            weekday: 1,
            startSection: 1,
            endSection: 2,
            type: ScheduleOverrideType.modify,
            targetCourseId: 'course-1',
            courseName: '高等数学-调课',
            teacher: '李老师',
            location: '教二-202',
            sourceCourseName: '高等数学',
            sourceTeacher: '张老师',
            sourceLocation: '教一-101',
            sourceStartSection: 1,
            sourceEndSection: 2,
          ),
        );

        expect(provider.overrides.single.status, ScheduleOverrideStatus.normal);

        await provider.setCourses([
          _buildCourse(teacher: '王老师', slotTeacher: ''),
        ], semesterCode: '20252');

        expect(
          provider.overrides.single.status,
          ScheduleOverrideStatus.orphaned,
        );
        final display = provider.getDisplaySlotAt(1, 1, 1);
        expect(display, isNotNull);
        expect(display!.isActive, isTrue);
        expect(display.overrideType, isNull);
        expect(display.slot.courseName, '高等数学');
      },
    );

    test(
      'legacy modify override without targetCourseId uses source sections',
      () async {
        final provider = ScheduleProvider();
        await provider.setCourses([
          _buildCourse(teacher: '张老师', slotTeacher: ''),
        ], semesterCode: '20252');
        final date = provider.getDateForSlot(1, 1);

        await provider.upsertOverride(
          ScheduleOverride(
            id: 'override-legacy-modify',
            semesterCode: '20252',
            dateKey: _dateKey(date),
            weekday: 1,
            startSection: 3,
            endSection: 4,
            type: ScheduleOverrideType.modify,
            courseName: '高等数学-调课',
            teacher: '李老师',
            location: '教二-202',
            sourceCourseName: '高等数学',
            sourceTeacher: '张老师',
            sourceLocation: '教一-101',
            sourceStartSection: 1,
            sourceEndSection: 2,
          ),
        );

        expect(provider.overrides.single.status, ScheduleOverrideStatus.normal);
        expect(provider.getDisplaySlotAt(1, 1, 1), isNull);

        final movedDisplay = provider.getDisplaySlotAt(1, 1, 3);
        expect(movedDisplay, isNotNull);
        expect(movedDisplay!.isActive, isTrue);
        expect(movedDisplay.overrideType, ScheduleOverrideType.modify);
        expect(movedDisplay.slot.startSection, 3);
        expect(movedDisplay.slot.endSection, 4);
        expect(movedDisplay.slot.courseName, '高等数学-调课');
        expect(movedDisplay.teacher, '李老师');
      },
    );
  });
}

Course _buildCourse({required String teacher, required String slotTeacher}) {
  return Course(
    id: 'course-1',
    code: 'MATH001',
    name: '高等数学',
    className: '数学一班',
    teacher: teacher,
    college: '理学院',
    credits: 4,
    totalHours: 64,
    semester: '20252',
    slots: [
      ScheduleSlot(
        courseId: 'course-1',
        courseName: '高等数学',
        teacher: slotTeacher,
        weekday: 1,
        startSection: 1,
        endSection: 2,
        location: '教一-101',
        weekRanges: [WeekRange(start: 1, end: 16)],
      ),
    ],
  );
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
