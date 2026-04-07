import 'package:flutter/material.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/services/schedule_provider.dart';

String scheduleDialogDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String formatScheduleDialogDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String newScheduleOverrideId() =>
    DateTime.now().microsecondsSinceEpoch.toString();

ScheduleOverrideType resolveScheduleOverrideEditType(
  ScheduleOverride? override,
) {
  return override?.type == ScheduleOverrideType.add
      ? ScheduleOverrideType.add
      : ScheduleOverrideType.modify;
}

String scheduleOverrideActionLabel(ScheduleOverride? override) {
  return override == null ? '调整本次安排' : '编辑临时安排';
}

String scheduleOverrideFormTitle(ScheduleOverrideType type) {
  return type == ScheduleOverrideType.add ? '新增临时课程' : '调整本次安排';
}

String scheduleOverrideSavedMessage(ScheduleOverrideType type) {
  return type == ScheduleOverrideType.add ? '已添加临时课程' : '已保存临时调整';
}

ScheduleOverride buildCancelScheduleOverride({
  required String semesterCode,
  required int weekday,
  required DateTime date,
  required DisplayScheduleSlot displaySlot,
}) {
  final slot = displaySlot.slot;
  final sourceOverride = displaySlot.sourceOverride;
  return ScheduleOverride(
    id: sourceOverride?.id ?? newScheduleOverrideId(),
    semesterCode: semesterCode,
    dateKey: scheduleDialogDateKey(date),
    weekday: weekday,
    startSection: slot.startSection,
    endSection: slot.endSection,
    type: ScheduleOverrideType.cancel,
    targetCourseId: slot.courseId,
    courseName: slot.courseName,
    teacher: displaySlot.teacher,
    location: slot.location,
    sourceCourseName: slot.courseName,
    sourceTeacher: displaySlot.teacher,
    sourceLocation: slot.location,
    sourceStartSection: slot.startSection,
    sourceEndSection: slot.endSection,
  );
}

Future<void> saveCancelScheduleOverride(
  BuildContext context, {
  required ScheduleProvider provider,
  required int weekday,
  required DateTime date,
  required DisplayScheduleSlot displaySlot,
}) async {
  final override = buildCancelScheduleOverride(
    semesterCode: provider.currentSemesterCode ?? '20252',
    weekday: weekday,
    date: date,
    displaySlot: displaySlot,
  );
  await provider.upsertOverride(override);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('已标记本次停课')));
}

Future<void> removeScheduleSlotOverride(
  BuildContext context, {
  required ScheduleProvider provider,
  required ScheduleOverride override,
}) async {
  await provider.removeOverride(override.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('已删除临时覆盖')));
}

ScheduleOverride buildScheduleOccurrenceOverride({
  required String semesterCode,
  required DateTime date,
  required int weekday,
  required ScheduleOverrideType type,
  required int startSection,
  required int endSection,
  required String courseName,
  required String teacher,
  required String location,
  required String note,
  ScheduleOverride? initialOverride,
  ScheduleSlot? sourceSlot,
  required String sourceTeacher,
}) {
  return ScheduleOverride(
    id: initialOverride?.id ?? newScheduleOverrideId(),
    semesterCode: semesterCode,
    dateKey: scheduleDialogDateKey(date),
    weekday: weekday,
    startSection: startSection,
    endSection: endSection,
    type: type,
    targetCourseId:
        type == ScheduleOverrideType.add ? null : sourceSlot?.courseId,
    courseName: courseName,
    teacher: teacher,
    location: location,
    note: note,
    sourceCourseName: sourceSlot?.courseName ?? '',
    sourceTeacher: sourceTeacher,
    sourceLocation: sourceSlot?.location ?? '',
    sourceStartSection: sourceSlot?.startSection,
    sourceEndSection: sourceSlot?.endSection,
  );
}

String formatScheduleWeekList(List<int> weeks) {
  if (weeks.isEmpty) return '';
  final parts = <String>[];
  var start = weeks[0];
  var end = weeks[0];
  for (var i = 1; i < weeks.length; i++) {
    if (weeks[i] == end + 1) {
      end = weeks[i];
    } else {
      parts.add(start == end ? '$start周' : '$start-$end周');
      start = end = weeks[i];
    }
  }
  parts.add(start == end ? '$start周' : '$start-$end周');
  return parts.join('，');
}

String? buildOriginalScheduleSummary(ScheduleOverride? override) {
  if (override == null || override.type == ScheduleOverrideType.add) {
    return null;
  }
  final pieces = <String>[];
  if (override.sourceCourseName.isNotEmpty) {
    pieces.add(override.sourceCourseName);
  }
  if (override.sourceStartSection != null &&
      override.sourceEndSection != null) {
    pieces.add('第${override.sourceStartSection}-${override.sourceEndSection}节');
  }
  if (override.sourceLocation.isNotEmpty) {
    pieces.add(override.sourceLocation);
  }
  if (override.sourceTeacher.isNotEmpty) {
    pieces.add(override.sourceTeacher);
  }
  return pieces.isEmpty ? null : pieces.join(' · ');
}

String scheduleOverrideTypeLabel(ScheduleOverrideType type) {
  return switch (type) {
    ScheduleOverrideType.add => '临时加课',
    ScheduleOverrideType.cancel => '本次停课',
    ScheduleOverrideType.modify => '临时调整',
  };
}

Color scheduleOverrideTypeColor(ThemeData theme, ScheduleOverrideType type) {
  return switch (type) {
    ScheduleOverrideType.add => theme.colorScheme.primary,
    ScheduleOverrideType.cancel => theme.colorScheme.error,
    ScheduleOverrideType.modify => const Color(0xFFB26A00),
  };
}

List<String> collectScheduleOverrideConflicts({
  required ScheduleProvider provider,
  required int week,
  required int weekday,
  required int startSection,
  required int endSection,
  ScheduleSlot? sourceSlot,
  ScheduleOverride? initialOverride,
}) {
  final conflicts = <String>{};
  for (var section = startSection; section <= endSection; section++) {
    final displaySlot = provider.getDisplaySlotAt(week, weekday, section);
    if (displaySlot == null || !displaySlot.isActive) continue;

    final slot = displaySlot.slot;
    final sameSource =
        sourceSlot != null && slot.courseId == sourceSlot.courseId;
    final sameOverride =
        initialOverride != null &&
        displaySlot.sourceOverride?.id == initialOverride.id;
    if (sameSource || sameOverride) continue;

    conflicts.add(
      '${slot.courseName}（第${slot.startSection}-${slot.endSection}节）',
    );
  }
  return conflicts.toList()..sort();
}

Future<bool> confirmScheduleOverrideConflict(
  BuildContext context, {
  required List<String> conflicts,
}) async {
  final summary = conflicts.join('\n');
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('发现时间冲突'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Text('目标时段已经有以下课程或临时安排：\n\n$summary\n\n仍然继续保存吗？'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('仍然保存'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
