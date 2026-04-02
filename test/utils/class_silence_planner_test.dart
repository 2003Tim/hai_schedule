import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:hai_schedule/models/class_silence_models.dart';
import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/class_silence_planner.dart';
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
      code: 'ENG001',
      name: '大学英语',
      className: '英语一班',
      teacher: '李老师',
      college: '外国语学院',
      credits: 2,
      totalHours: 32,
      semester: '2025-2026-2',
      slots: [
        ScheduleSlot(
          courseId: 'course-1',
          courseName: '大学英语',
          weekday: 1,
          startSection: 1,
          endSection: 2,
          location: '教学楼 A101',
          weekRanges: [WeekRange(start: 1, end: 16)],
        ),
        ScheduleSlot(
          courseId: 'course-1',
          courseName: '大学英语',
          weekday: 1,
          startSection: 5,
          endSection: 6,
          location: '教学楼 A101',
          weekRanges: [WeekRange(start: 1, end: 16)],
        ),
      ],
    );

    final events = ClassSilencePlanner.buildEvents(
      courses: [course],
      overrides: const [
        ScheduleOverride(
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
      ],
      weekCalc: WeekCalculator(
        semesterStart: DateTime(2026, 3, 2),
        totalWeeks: 20,
      ),
      timeConfig: SchoolTimeConfig.hainanuDefault(),
      now: tz.TZDateTime(location, 2026, 3, 2, 0, 0),
      horizonEnd: tz.TZDateTime(location, 2026, 3, 8, 23, 59),
      location: location,
    );

    expect(events, hasLength(2));
    expect(events[0].startSection, 3);
    expect(events[1].startSection, 5);
  });

  test('add override creates temporary silence event', () {
    final events = ClassSilencePlanner.buildEvents(
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
        ),
      ],
      weekCalc: WeekCalculator(
        semesterStart: DateTime(2026, 3, 2),
        totalWeeks: 20,
      ),
      timeConfig: SchoolTimeConfig.hainanuDefault(),
      now: tz.TZDateTime(location, 2026, 3, 2, 0, 0),
      horizonEnd: tz.TZDateTime(location, 2026, 3, 8, 23, 59),
      location: location,
    );

    expect(events, hasLength(1));
    expect(events.single.courseName, '临时课程');
    expect(events.single.date, '2026-03-03');
  });

  test('silence event serializes to channel payload', () {
    const event = SilenceScheduleEvent(
      id: 'test-id',
      courseName: '大学英语',
      date: '2026-03-03',
      startSection: 1,
      endSection: 2,
      startAtMillis: 1,
      endAtMillis: 2,
    );

    expect(event.toJson(), {
      'id': 'test-id',
      'courseName': '大学英语',
      'date': '2026-03-03',
      'startSection': 1,
      'endSection': 2,
      'startAtMillis': 1,
      'endAtMillis': 2,
    });
  });
}
