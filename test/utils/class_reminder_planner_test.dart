import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/class_reminder_planner.dart';
import 'package:hai_schedule/utils/week_calculator.dart';

void main() {
  late tz.Location location;

  setUpAll(() {
    tz.initializeTimeZones();
    location = tz.getLocation('Asia/Shanghai');
    tz.setLocalLocation(location);
  });

  test('modify override with explicit source sections keeps other slots', () {
    final course = Course(
      id: 'course-1',
      code: 'MATH001',
      name: '高等数学',
      className: '数理一班',
      teacher: '李老师',
      college: '数学学院',
      credits: 4,
      totalHours: 64,
      semester: '2025-2026-2',
      slots: [
        ScheduleSlot(
          courseId: 'course-1',
          courseName: '高等数学',
          weekday: 1,
          startSection: 1,
          endSection: 2,
          location: '教学楼 A101',
          weekRanges: [WeekRange(start: 1, end: 16)],
        ),
        ScheduleSlot(
          courseId: 'course-1',
          courseName: '高等数学',
          weekday: 1,
          startSection: 5,
          endSection: 6,
          location: '教学楼 A101',
          weekRanges: [WeekRange(start: 1, end: 16)],
        ),
      ],
    );

    final overrides = [
      const ScheduleOverride(
        id: 'override-1',
        semesterCode: '20252',
        dateKey: '2026-03-02',
        weekday: 1,
        startSection: 3,
        endSection: 4,
        type: ScheduleOverrideType.modify,
        targetCourseId: 'course-1',
        location: '教学楼 B203',
        sourceStartSection: 1,
        sourceEndSection: 2,
      ),
    ];

    final occurrences = ClassReminderPlanner.buildOccurrences(
      courses: [course],
      overrides: overrides,
      weekCalc: WeekCalculator(
        semesterStart: DateTime(2026, 3, 2),
        totalWeeks: 20,
      ),
      timeConfig: SchoolTimeConfig.hainanuDefault(),
      leadMinutes: 10,
      now: tz.TZDateTime(location, 2026, 3, 2, 0, 0),
      horizonEnd: tz.TZDateTime(location, 2026, 3, 8, 23, 59),
      location: location,
      payloadType: 'class_reminder',
    );

    expect(occurrences, hasLength(2));
    expect(occurrences[0].payload['startSection'], 3);
    expect(occurrences[0].payload['location'], '教学楼 B203');
    expect(occurrences[1].payload['startSection'], 5);
  });

  test('add override creates temporary reminder preview item', () {
    final occurrences = ClassReminderPlanner.buildOccurrences(
      courses: const [],
      overrides: const [
        ScheduleOverride(
          id: 'override-add-1',
          semesterCode: '20252',
          dateKey: '2026-03-03',
          weekday: 2,
          startSection: 1,
          endSection: 2,
          type: ScheduleOverrideType.add,
          location: '实验楼 204',
        ),
      ],
      weekCalc: WeekCalculator(
        semesterStart: DateTime(2026, 3, 2),
        totalWeeks: 20,
      ),
      timeConfig: SchoolTimeConfig.hainanuDefault(),
      leadMinutes: 15,
      now: tz.TZDateTime(location, 2026, 3, 2, 0, 0),
      horizonEnd: tz.TZDateTime(location, 2026, 3, 8, 23, 59),
      location: location,
      payloadType: 'class_reminder',
    );

    expect(occurrences, hasLength(1));
    expect(occurrences.single.title, '15 分钟后上课');
    expect(occurrences.single.body, contains('临时课程'));

    final preview = ClassReminderPlanner.previewItemFromOccurrence(
      occurrences.single,
    );
    expect(preview.courseName, '临时课程');
    expect(preview.location, '实验楼 204');
    expect(preview.dateLabel, '2026-03-03');
  });
}
