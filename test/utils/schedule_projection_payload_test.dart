import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/utils/schedule_projection_payload.dart';
import 'package:hai_schedule/utils/week_calculator.dart';

void main() {
  test('build matches shared projection fixture contract', () async {
    final fixture = json.decode(
          await File(
            'test/fixtures/schedule_projection_payload_v2.json',
          ).readAsString(),
        )
        as Map<String, dynamic>;

    final payload = ScheduleProjectionPayload.build(
      courses: [
        Course(
          id: 'math',
          code: 'MATH001',
          name: 'Linear Algebra',
          className: 'Math 1',
          teacher: 'Prof A',
          college: 'Science',
          credits: 4,
          totalHours: 64,
          semester: '20251',
          slots: [
            ScheduleSlot(
              courseId: 'math',
              courseName: 'Linear Algebra',
              teacher: 'Prof A',
              weekday: 1,
              startSection: 1,
              endSection: 2,
              location: 'A101',
              weekRanges: [WeekRange(start: 1, end: 3)],
            ),
          ],
        ),
        Course(
          id: 'chem',
          code: 'CHEM001',
          name: 'Chemistry',
          className: 'Chem 1',
          teacher: 'Prof B',
          college: 'Science',
          credits: 3,
          totalHours: 48,
          semester: '20251',
          slots: [
            ScheduleSlot(
              courseId: 'chem',
              courseName: 'Chemistry',
              teacher: 'Prof B',
              weekday: 1,
              startSection: 3,
              endSection: 4,
              location: 'B201',
              weekRanges: [WeekRange(start: 1, end: 3)],
            ),
          ],
        ),
      ],
      overrides: const [
        ScheduleOverride(
          id: 'modify-math',
          semesterCode: '20251',
          dateKey: '2026-03-02',
          weekday: 1,
          startSection: 2,
          endSection: 3,
          type: ScheduleOverrideType.modify,
          targetCourseId: 'math',
          courseName: 'Advanced Algebra',
          location: 'A301',
          sourceStartSection: 1,
          sourceEndSection: 2,
        ),
        ScheduleOverride(
          id: 'cancel-chem',
          semesterCode: '20251',
          dateKey: '2026-03-02',
          weekday: 1,
          startSection: 3,
          endSection: 4,
          type: ScheduleOverrideType.cancel,
          targetCourseId: 'chem',
        ),
        ScheduleOverride(
          id: 'add-temp',
          semesterCode: '20251',
          dateKey: '2026-03-02',
          weekday: 1,
          startSection: 4,
          endSection: 4,
          type: ScheduleOverrideType.add,
          courseName: 'Temporary',
          teacher: 'Prof C',
          location: 'Lab 1',
        ),
      ],
      weekCalc: WeekCalculator(
        semesterStart: DateTime.utc(2026, 3, 2),
        totalWeeks: 20,
      ),
      timeConfig: SchoolTimeConfig(
        name: 'Fixture',
        classTimes: [
          ClassTime(section: 1, startTime: '08:00', endTime: '08:45'),
          ClassTime(section: 2, startTime: '08:55', endTime: '09:40'),
          ClassTime(section: 3, startTime: '10:10', endTime: '10:55'),
          ClassTime(section: 4, startTime: '11:05', endTime: '11:50'),
          ClassTime(section: 5, startTime: '14:00', endTime: '14:45'),
          ClassTime(section: 6, startTime: '14:55', endTime: '15:40'),
        ],
      ),
      generatedAt: DateTime.utc(2026, 3, 1),
    );

    expect(payload, fixture);
  });
}
