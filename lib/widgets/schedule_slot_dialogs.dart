import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../services/schedule_provider.dart';
import '../utils/constants.dart';

// ---------------------------------------------------------------------------
// 共享的课程格子交互对话框
// 供 ScheduleGrid（周视图）和 DailyScheduleView（日视图）共同使用。
// ---------------------------------------------------------------------------

/// 长按课程格子后弹出的操作菜单。
Future<void> openScheduleSlotMenu(
  BuildContext context, {
  required ScheduleProvider provider,
  required int week,
  required int weekday,
  required DisplayScheduleSlot displaySlot,
}) async {
  final slot = displaySlot.slot;
  final date = provider.getDateForSlot(week, weekday);
  final sourceOverride = displaySlot.sourceOverride;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(slot.courseName),
              subtitle: Text(
                '${_formatDate(date)} 第${slot.startSection}-${slot.endSection}节',
              ),
            ),
            if (displaySlot.canMarkCancel)
              ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('本次停课'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await provider.upsertOverride(
                    ScheduleOverride(
                      id: sourceOverride?.id ?? _newOverrideId(),
                      semesterCode: provider.currentSemesterCode ?? '20252',
                      dateKey: _dateKey(date),
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
                    ),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已标记本次停课')),
                  );
                },
              ),
            if (displaySlot.canAdjustOccurrence)
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: Text(
                  sourceOverride == null ? '调整本次安排' : '编辑临时安排',
                ),
                onTap: () {
                  final editType =
                      sourceOverride?.type == ScheduleOverrideType.add
                          ? ScheduleOverrideType.add
                          : ScheduleOverrideType.modify;
                  Navigator.of(sheetContext).pop();
                  openScheduleOverrideForm(
                    context,
                    provider: provider,
                    week: week,
                    weekday: weekday,
                    type: editType,
                    initialOverride: sourceOverride,
                    sourceSlot: slot,
                    sourceTeacher: displaySlot.teacher,
                  );
                },
              ),
            if (displaySlot.isReferenceOnly)
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('本周不开设'),
                subtitle: Text(
                  '这节课只是为了参考显示，不对应本周实际课次，所以不能直接停课或调整。',
                ),
              ),
            if (sourceOverride != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除临时覆盖'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await provider.removeOverride(sourceOverride.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已删除临时覆盖')),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// 点击课程格子后弹出的详情面板。
Future<void> openScheduleSlotDetails(
  BuildContext context, {
  required ScheduleProvider provider,
  required int week,
  required int weekday,
  required DisplayScheduleSlot displaySlot,
}) async {
  final slot = displaySlot.slot;
  final date = provider.getDateForSlot(week, weekday);
  final sourceOverride = displaySlot.sourceOverride;
  final times = provider.timeConfig.getSlotTime(
    slot.startSection,
    slot.endSection,
  );
  final color = CourseColors.getColor(slot.courseName);
  final activeWeeks = slot.getAllActiveWeeks();
  final originalSummary = _buildOriginalSummary(sourceOverride);

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.courseName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip(
                              context: sheetContext,
                              label:
                                  '${_formatDate(date)} ${WeekdayNames.getShort(weekday)}',
                              icon: Icons.calendar_today_rounded,
                            ),
                            _buildChip(
                              context: sheetContext,
                              label:
                                  '第${slot.startSection}-${slot.endSection}节',
                              icon: Icons.schedule_rounded,
                            ),
                            if (displaySlot.isReferenceOnly)
                              _buildChip(
                                context: sheetContext,
                                label: '非本周参考',
                                icon: Icons.visibility_outlined,
                                color: theme.colorScheme.outline,
                              ),
                            if (displaySlot.overrideType != null)
                              _buildChip(
                                context: sheetContext,
                                label: _overrideLabel(displaySlot.overrideType!),
                                icon: Icons.edit_calendar_outlined,
                                color: _overrideColor(
                                  theme,
                                  displaySlot.overrideType!,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow(
                icon: Icons.access_time_rounded,
                label: '上课时间',
                value:
                    '第${slot.startSection}-${slot.endSection}节 ${times?.$1 ?? ''} - ${times?.$2 ?? ''}',
              ),
              _detailRow(
                icon: Icons.location_on_rounded,
                label: '上课地点',
                value: slot.location.isEmpty ? '未填写' : slot.location,
              ),
              if (displaySlot.teacher.isNotEmpty)
                _detailRow(
                  icon: Icons.person_rounded,
                  label: '授课教师',
                  value: displaySlot.teacher,
                ),
              if (sourceOverride?.note.trim().isNotEmpty == true)
                _detailRow(
                  icon: Icons.sticky_note_2_outlined,
                  label: '备注',
                  value: sourceOverride!.note.trim(),
                ),
              if (activeWeeks.isNotEmpty)
                _detailRow(
                  icon: Icons.date_range_rounded,
                  label: '周次范围',
                  value: _formatWeekList(activeWeeks),
                ),
              if (displaySlot.isReferenceOnly)
                _detailRow(
                  icon: Icons.info_outline_rounded,
                  label: '当前状态',
                  value: '这门课在第$week周不开设，这里只是参考展示，不对应本周实际课次。',
                ),
              if (originalSummary != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '原安排',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        originalSummary,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (displaySlot.canMarkCancel)
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await provider.upsertOverride(
                          ScheduleOverride(
                            id: sourceOverride?.id ?? _newOverrideId(),
                            semesterCode:
                                provider.currentSemesterCode ?? '20252',
                            dateKey: _dateKey(date),
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
                          ),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已标记本次停课')),
                        );
                      },
                      icon: const Icon(Icons.event_busy_outlined, size: 18),
                      label: const Text('本次停课'),
                    ),
                  if (displaySlot.canAdjustOccurrence)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        final editType =
                            sourceOverride?.type == ScheduleOverrideType.add
                                ? ScheduleOverrideType.add
                                : ScheduleOverrideType.modify;
                        openScheduleOverrideForm(
                          context,
                          provider: provider,
                          week: week,
                          weekday: weekday,
                          type: editType,
                          initialOverride: sourceOverride,
                          sourceSlot: slot,
                          sourceTeacher: displaySlot.teacher,
                        );
                      },
                      icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                      label: Text(
                        sourceOverride == null ? '调整本次安排' : '编辑临时安排',
                      ),
                    ),
                  if (sourceOverride != null)
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await provider.removeOverride(sourceOverride.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已删除临时覆盖')),
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('删除临时覆盖'),
                    ),
                  if (displaySlot.overrideType == ScheduleOverrideType.cancel)
                    Text(
                      '当前已经标记为"本次停课"。如果你想改成调课，请先删除这条停课安排，再重新创建临时调整。',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    ),
                  if (displaySlot.isReferenceOnly)
                    Text(
                      '这门课在本周并不开设，所以这里没有"本次停课"或"调整本次安排"的对象。',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.62,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// 新增或编辑临时课程/调整的表单。
Future<void> openScheduleOverrideForm(
  BuildContext context, {
  required ScheduleProvider provider,
  required int week,
  required int weekday,
  required ScheduleOverrideType type,
  ScheduleOverride? initialOverride,
  ScheduleSlot? sourceSlot,
  String sourceTeacher = '',
  int? initialStartSection,
  int? initialEndSection,
}) async {
  final date = provider.getDateForSlot(week, weekday);
  final title = type == ScheduleOverrideType.add ? '新增临时课程' : '调整本次安排';
  final totalSections = provider.timeConfig.totalSections;
  final nameController = TextEditingController(
    text:
        initialOverride?.courseName.isNotEmpty == true
            ? initialOverride!.courseName
            : sourceSlot?.courseName ?? '',
  );
  final teacherController = TextEditingController(
    text:
        initialOverride?.teacher.isNotEmpty == true
            ? initialOverride!.teacher
            : sourceTeacher,
  );
  final locationController = TextEditingController(
    text:
        initialOverride?.location.isNotEmpty == true
            ? initialOverride!.location
            : sourceSlot?.location ?? '',
  );
  final noteController = TextEditingController(
    text: initialOverride?.note ?? '',
  );
  int startSection =
      initialOverride?.startSection ??
      sourceSlot?.startSection ??
      initialStartSection ??
      1;
  int endSection =
      initialOverride?.endSection ??
      sourceSlot?.endSection ??
      initialEndSection ??
      startSection;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          if (startSection > totalSections) startSection = totalSections;
          if (endSection < startSection) endSection = startSection;
          if (endSection > totalSections) endSection = totalSections;

          final startItems = List.generate(totalSections, (i) => i + 1);
          final endItems = List.generate(
            totalSections - startSection + 1,
            (i) => startSection + i,
          );

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatDate(date)} 周${WeekdayNames.getShort(weekday)}',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(
                          alpha: 0.68,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '课程名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('start-$startSection-$endSection'),
                            initialValue: startSection,
                            decoration: const InputDecoration(
                              labelText: '开始节次',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                startItems
                                    .map(
                                      (v) => DropdownMenuItem<int>(
                                        value: v,
                                        child: Text('第$v节'),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setModalState(() {
                                startSection = v;
                                if (endSection < startSection) {
                                  endSection = startSection;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey('end-$startSection-$endSection'),
                            initialValue: endSection,
                            decoration: const InputDecoration(
                              labelText: '结束节次',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                endItems
                                    .map(
                                      (v) => DropdownMenuItem<int>(
                                        value: v,
                                        child: Text('第$v节'),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setModalState(() => endSection = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: '地点',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: teacherController,
                      decoration: const InputDecoration(
                        labelText: '教师',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        hintText: '例如：调到实验楼、和某课程换课、临时补课说明',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final courseName = nameController.text.trim();
                          if (courseName.isEmpty &&
                              type == ScheduleOverrideType.add) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('请先填写课程名称')),
                            );
                            return;
                          }

                          final conflicts = _collectOverrideConflicts(
                            provider: provider,
                            week: week,
                            weekday: weekday,
                            startSection: startSection,
                            endSection: endSection,
                            sourceSlot: sourceSlot,
                            initialOverride: initialOverride,
                          );
                          if (conflicts.isNotEmpty) {
                            final confirmed = await _confirmConflictOverride(
                              ctx,
                              conflicts: conflicts,
                            );
                            if (!confirmed || !context.mounted) return;
                          }

                          final override = ScheduleOverride(
                            id: initialOverride?.id ?? _newOverrideId(),
                            semesterCode:
                                provider.currentSemesterCode ?? '20252',
                            dateKey: _dateKey(date),
                            weekday: weekday,
                            startSection: startSection,
                            endSection: endSection,
                            type: type,
                            targetCourseId:
                                type == ScheduleOverrideType.add
                                    ? null
                                    : sourceSlot?.courseId,
                            courseName: courseName,
                            teacher: teacherController.text.trim(),
                            location: locationController.text.trim(),
                            note: noteController.text.trim(),
                            sourceCourseName: sourceSlot?.courseName ?? '',
                            sourceTeacher: sourceTeacher,
                            sourceLocation: sourceSlot?.location ?? '',
                            sourceStartSection: sourceSlot?.startSection,
                            sourceEndSection: sourceSlot?.endSection,
                          );
                          await provider.upsertOverride(override);
                          if (!context.mounted) return;
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                type == ScheduleOverrideType.add
                                    ? '已添加临时课程'
                                    : '已保存临时调整',
                              ),
                            ),
                          );
                        },
                        child: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _newOverrideId() => DateTime.now().microsecondsSinceEpoch.toString();

Widget _buildChip({
  required BuildContext context,
  required String label,
  required IconData icon,
  Color? color,
}) {
  final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: resolvedColor.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: resolvedColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: resolvedColor,
          ),
        ),
      ],
    ),
  );
}

Widget _detailRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: Colors.grey[500]),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

String _formatWeekList(List<int> weeks) {
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

String? _buildOriginalSummary(ScheduleOverride? override) {
  if (override == null || override.type == ScheduleOverrideType.add) return null;
  final pieces = <String>[];
  if (override.sourceCourseName.isNotEmpty) pieces.add(override.sourceCourseName);
  if (override.sourceStartSection != null && override.sourceEndSection != null) {
    pieces.add('第${override.sourceStartSection}-${override.sourceEndSection}节');
  }
  if (override.sourceLocation.isNotEmpty) pieces.add(override.sourceLocation);
  if (override.sourceTeacher.isNotEmpty) pieces.add(override.sourceTeacher);
  return pieces.isEmpty ? null : pieces.join(' · ');
}

String _overrideLabel(ScheduleOverrideType type) {
  return switch (type) {
    ScheduleOverrideType.add => '临时加课',
    ScheduleOverrideType.cancel => '本次停课',
    ScheduleOverrideType.modify => '临时调整',
  };
}

Color _overrideColor(ThemeData theme, ScheduleOverrideType type) {
  return switch (type) {
    ScheduleOverrideType.add => theme.colorScheme.primary,
    ScheduleOverrideType.cancel => theme.colorScheme.error,
    ScheduleOverrideType.modify => const Color(0xFFB26A00),
  };
}

List<String> _collectOverrideConflicts({
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

Future<bool> _confirmConflictOverride(
  BuildContext context, {
  required List<String> conflicts,
}) async {
  final summary = conflicts.join('\n');
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('发现时间冲突'),
        content: Text('目标时段已经有以下课程或临时安排：\n\n$summary\n\n仍然继续保存吗？'),
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
