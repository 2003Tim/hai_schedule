import 'package:flutter/material.dart';

import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/utils/constants.dart';
import 'package:hai_schedule/utils/schedule_slot_dialog_utils.dart';
import 'package:hai_schedule/widgets/schedule_override_form_sheet.dart';

class ScheduleSlotMenuSheet extends StatelessWidget {
  const ScheduleSlotMenuSheet({
    super.key,
    required this.hostContext,
    required this.provider,
    required this.week,
    required this.weekday,
    required this.date,
    required this.displaySlot,
  });

  final BuildContext hostContext;
  final ScheduleProvider provider;
  final int week;
  final int weekday;
  final DateTime date;
  final DisplayScheduleSlot displaySlot;

  ScheduleOverride? get _sourceOverride => displaySlot.sourceOverride;

  Future<void> _markCancel(BuildContext context) async {
    Navigator.of(context).pop();
    await saveCancelScheduleOverride(
      hostContext,
      provider: provider,
      weekday: weekday,
      date: date,
      displaySlot: displaySlot,
    );
  }

  void _editOccurrence(BuildContext context) {
    Navigator.of(context).pop();
    if (!hostContext.mounted) return;
    openScheduleOverrideForm(
      hostContext,
      provider: provider,
      week: week,
      weekday: weekday,
      type: resolveScheduleOverrideEditType(_sourceOverride),
      initialOverride: _sourceOverride,
      sourceSlot: displaySlot.slot,
      sourceTeacher: displaySlot.teacher,
    );
  }

  Future<void> _deleteOverride(BuildContext context) async {
    final override = _sourceOverride;
    if (override == null) return;
    Navigator.of(context).pop();
    await removeScheduleSlotOverride(
      hostContext,
      provider: provider,
      override: override,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = displaySlot.slot;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(slot.courseName),
            subtitle: Text(
              '${formatScheduleDialogDate(date)} 第${slot.startSection}-${slot.endSection}节',
            ),
          ),
          if (displaySlot.canMarkCancel)
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('本次停课'),
              onTap: () => _markCancel(context),
            ),
          if (displaySlot.canAdjustOccurrence)
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: Text(scheduleOverrideActionLabel(_sourceOverride)),
              onTap: () => _editOccurrence(context),
            ),
          if (displaySlot.isReferenceOnly)
            const ListTile(
              leading: Icon(Icons.info_outline_rounded),
              title: Text('本周不开设'),
              subtitle: Text('这节课只是为了参考显示，不对应本周实际课次，所以不能直接停课或调整。'),
            ),
          if (_sourceOverride != null)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除临时覆盖'),
              onTap: () => _deleteOverride(context),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class ScheduleSlotDetailsSheet extends StatelessWidget {
  const ScheduleSlotDetailsSheet({
    super.key,
    required this.hostContext,
    required this.provider,
    required this.week,
    required this.weekday,
    required this.date,
    required this.displaySlot,
  });

  final BuildContext hostContext;
  final ScheduleProvider provider;
  final int week;
  final int weekday;
  final DateTime date;
  final DisplayScheduleSlot displaySlot;

  ScheduleOverride? get _sourceOverride => displaySlot.sourceOverride;

  Future<void> _markCancel(BuildContext context) async {
    Navigator.of(context).pop();
    await saveCancelScheduleOverride(
      hostContext,
      provider: provider,
      weekday: weekday,
      date: date,
      displaySlot: displaySlot,
    );
  }

  void _editOccurrence(BuildContext context) {
    Navigator.of(context).pop();
    if (!hostContext.mounted) return;
    openScheduleOverrideForm(
      hostContext,
      provider: provider,
      week: week,
      weekday: weekday,
      type: resolveScheduleOverrideEditType(_sourceOverride),
      initialOverride: _sourceOverride,
      sourceSlot: displaySlot.slot,
      sourceTeacher: displaySlot.teacher,
    );
  }

  Future<void> _deleteOverride(BuildContext context) async {
    final override = _sourceOverride;
    if (override == null) return;
    Navigator.of(context).pop();
    await removeScheduleSlotOverride(
      hostContext,
      provider: provider,
      override: override,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = displaySlot.slot;
    final theme = Theme.of(context);
    final color = CourseColors.getColor(slot.courseName);
    final times = provider.timeConfig.getSlotTime(
      slot.startSection,
      slot.endSection,
    );
    final activeWeeks = slot.getAllActiveWeeks();
    final originalSummary = buildOriginalScheduleSummary(_sourceOverride);

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
                          _ScheduleChip(
                            label:
                                '${formatScheduleDialogDate(date)} ${WeekdayNames.getShort(weekday)}',
                            icon: Icons.calendar_today_rounded,
                          ),
                          _ScheduleChip(
                            label: '第${slot.startSection}-${slot.endSection}节',
                            icon: Icons.schedule_rounded,
                          ),
                          if (displaySlot.isReferenceOnly)
                            _ScheduleChip(
                              label: '非本周参考',
                              icon: Icons.visibility_outlined,
                              color: theme.colorScheme.outline,
                            ),
                          if (displaySlot.overrideType != null)
                            _ScheduleChip(
                              label: scheduleOverrideTypeLabel(
                                displaySlot.overrideType!,
                              ),
                              icon: Icons.edit_calendar_outlined,
                              color: scheduleOverrideTypeColor(
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
            _ScheduleDetailRow(
              icon: Icons.access_time_rounded,
              label: '上课时间',
              value:
                  '第${slot.startSection}-${slot.endSection}节 ${times?.$1 ?? ''} - ${times?.$2 ?? ''}',
            ),
            _ScheduleDetailRow(
              icon: Icons.location_on_rounded,
              label: '上课地点',
              value: slot.location.isEmpty ? '未填写' : slot.location,
            ),
            if (displaySlot.teacher.isNotEmpty)
              _ScheduleDetailRow(
                icon: Icons.person_rounded,
                label: '授课教师',
                value: displaySlot.teacher,
              ),
            if (_sourceOverride?.note.trim().isNotEmpty == true)
              _ScheduleDetailRow(
                icon: Icons.sticky_note_2_outlined,
                label: '备注',
                value: _sourceOverride!.note.trim(),
              ),
            if (activeWeeks.isNotEmpty)
              _ScheduleDetailRow(
                icon: Icons.date_range_rounded,
                label: '周次范围',
                value: formatScheduleWeekList(activeWeeks),
              ),
            if (displaySlot.isReferenceOnly)
              _ScheduleDetailRow(
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
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.45,
                  ),
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
                    onPressed: () => _markCancel(context),
                    icon: const Icon(Icons.event_busy_outlined, size: 18),
                    label: const Text('本次停课'),
                  ),
                if (displaySlot.canAdjustOccurrence)
                  OutlinedButton.icon(
                    onPressed: () => _editOccurrence(context),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    label: Text(scheduleOverrideActionLabel(_sourceOverride)),
                  ),
                if (_sourceOverride != null)
                  TextButton.icon(
                    onPressed: () => _deleteOverride(context),
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
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({required this.label, required this.icon, this.color});

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
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
}

class _ScheduleDetailRow extends StatelessWidget {
  const _ScheduleDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
}
