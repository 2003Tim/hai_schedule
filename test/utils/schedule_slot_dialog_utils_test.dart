import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/display_schedule_slot.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/utils/schedule_slot_dialog_utils.dart';

void main() {
  group('schedule_slot_dialog_utils', () {
    test('formats week list into merged ranges', () {
      expect(formatScheduleWeekList([1, 2, 3, 5, 7, 8]), '1-3周，5周，7-8周');
    });

    test('builds original summary from source fields', () {
      const override = ScheduleOverride(
        id: 'override-1',
        semesterCode: '20252',
        dateKey: '2026-04-02',
        weekday: 4,
        startSection: 3,
        endSection: 4,
        type: ScheduleOverrideType.modify,
        sourceCourseName: '高等数学',
        sourceTeacher: '张老师',
        sourceLocation: '教学楼 A101',
        sourceStartSection: 1,
        sourceEndSection: 2,
      );

      expect(
        buildOriginalScheduleSummary(override),
        '高等数学 · 第1-2节 · 教学楼 A101 · 张老师',
      );
      expect(
        buildOriginalScheduleSummary(
          const ScheduleOverride(
            id: 'override-2',
            semesterCode: '20252',
            dateKey: '2026-04-02',
            weekday: 4,
            startSection: 3,
            endSection: 4,
            type: ScheduleOverrideType.add,
          ),
        ),
        isNull,
      );
    });

    test('builds cancel override from active display slot', () {
      final displaySlot = DisplayScheduleSlot(
        slot: ScheduleSlot(
          courseId: 'course-1',
          courseName: '大学英语',
          weekday: 4,
          startSection: 3,
          endSection: 4,
          location: '教一 204',
          weekRanges: [WeekRange(start: 1, end: 16)],
        ),
        teacher: '李老师',
        isActive: true,
        sourceOverride: const ScheduleOverride(
          id: 'existing',
          semesterCode: '20252',
          dateKey: '2026-04-02',
          weekday: 4,
          startSection: 3,
          endSection: 4,
          type: ScheduleOverrideType.modify,
        ),
      );

      final override = buildCancelScheduleOverride(
        semesterCode: '20252',
        weekday: 4,
        date: DateTime(2026, 4, 2),
        displaySlot: displaySlot,
      );

      expect(override.id, 'existing');
      expect(override.type, ScheduleOverrideType.cancel);
      expect(override.targetCourseId, 'course-1');
      expect(override.sourceTeacher, '李老师');
      expect(override.sourceLocation, '教一 204');
      expect(override.dateKey, '2026-04-02');
    });

    test('builds schedule occurrence override for add and modify', () {
      final sourceSlot = ScheduleSlot(
        courseId: 'course-2',
        courseName: '线性代数',
        weekday: 2,
        startSection: 1,
        endSection: 2,
        location: '教二 302',
        weekRanges: [WeekRange(start: 1, end: 18)],
      );

      final addOverride = buildScheduleOccurrenceOverride(
        semesterCode: '20252',
        date: DateTime(2026, 4, 7),
        weekday: 2,
        type: ScheduleOverrideType.add,
        startSection: 5,
        endSection: 6,
        courseName: '临时讲座',
        teacher: '王老师',
        location: '报告厅',
        note: '补充说明',
        sourceTeacher: '',
      );
      final modifyOverride = buildScheduleOccurrenceOverride(
        semesterCode: '20252',
        date: DateTime(2026, 4, 7),
        weekday: 2,
        type: ScheduleOverrideType.modify,
        startSection: 3,
        endSection: 4,
        courseName: '线性代数',
        teacher: '王老师',
        location: '教三 105',
        note: '',
        sourceSlot: sourceSlot,
        sourceTeacher: '刘老师',
      );

      expect(addOverride.targetCourseId, isNull);
      expect(addOverride.courseName, '临时讲座');
      expect(modifyOverride.targetCourseId, 'course-2');
      expect(modifyOverride.sourceCourseName, '线性代数');
      expect(modifyOverride.sourceTeacher, '刘老师');
      expect(modifyOverride.sourceStartSection, 1);
      expect(modifyOverride.sourceEndSection, 2);
    });
  });
}
