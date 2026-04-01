import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../services/schedule_provider.dart';
import '../services/theme_provider.dart';
import '../utils/constants.dart';

class DailyScheduleView extends StatelessWidget {
  final ScheduleProvider provider;
  final int week;
  final int weekday;

  const DailyScheduleView({
    super.key,
    required this.provider,
    required this.week,
    required this.weekday,
  });

  @override
  Widget build(BuildContext context) {
    final entries = provider.getDisplaySlotsForDay(week, weekday);
    final date = provider.getDateForSlot(week, weekday);

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 44,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.42),
              ),
              const SizedBox(height: 12),
              Text(
                '${_weekdayLabel(weekday)} ${date.month}/${date.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.86),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '\u8fd9\u4e00\u5929\u6ca1\u6709\u8bfe\u7a0b\u5b89\u6392',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed:
                    () => _openDailyOverrideForm(
                      context,
                      provider: provider,
                      week: week,
                      weekday: weekday,
                      type: ScheduleOverrideType.add,
                    ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('\u65b0\u589e\u4e34\u65f6\u5b89\u6392'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      itemCount: entries.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _DailyHeader(
            provider: provider,
            week: week,
            weekday: weekday,
            count: entries.length,
          );
        }
        final entry = entries[index - 1];
        return _DailyLessonCard(
          provider: provider,
          week: week,
          weekday: weekday,
          slot: entry,
          timeConfig: provider.timeConfig,
        );
      },
    );
  }
}

class _DailyHeader extends StatelessWidget {
  final ScheduleProvider provider;
  final int week;
  final int weekday;
  final int count;

  const _DailyHeader({
    required this.provider,
    required this.week,
    required this.weekday,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle =
        count == 0
            ? '\u4eca\u5929\u6682\u65f6\u6ca1\u6709\u8bfe\u7a0b\u5b89\u6392'
            : '\u4eca\u5929\u6709 $count \u8282\u8bfe\uff0c\u52a0\u6cb9\uff01';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _weekdayLabel(weekday),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.66),
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count \u8282\u5b89\u6392',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '\u65b0\u589e\u4e34\u65f6\u5b89\u6392',
              child: IconButton(
                onPressed:
                    () => _openDailyOverrideForm(
                      context,
                      provider: provider,
                      week: week,
                      weekday: weekday,
                      type: ScheduleOverrideType.add,
                    ),
                icon: const Icon(Icons.add_rounded),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DailyLessonCard extends StatelessWidget {
  final ScheduleProvider provider;
  final int week;
  final int weekday;
  final DisplayScheduleSlot slot;
  final SchoolTimeConfig timeConfig;

  const _DailyLessonCard({
    required this.provider,
    required this.week,
    required this.weekday,
    required this.slot,
    required this.timeConfig,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = CourseColors.getColor(slot.slot.courseName);
    final themeProvider = context.watch<ThemeProvider>();
    final isCancelled = slot.overrideType == ScheduleOverrideType.cancel;
    final isAdjusted = slot.overrideType == ScheduleOverrideType.modify;
    final isDimmed = !slot.isActive;
    final effectiveOpacity =
        isCancelled
            ? 0.24
            : isAdjusted
            ? 0.30
            : isDimmed
            ? 0.24
            : themeProvider.cardOpacity * 0.92;
    final times = timeConfig.getSlotTime(
      slot.slot.startSection,
      slot.slot.endSection,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap:
            () => _openDailySlotDetails(
              context,
              provider: provider,
              week: week,
              weekday: weekday,
              displaySlot: slot,
            ),
        onLongPress:
            () => _openDailySlotMenu(
              context,
              provider: provider,
              week: week,
              weekday: weekday,
              displaySlot: slot,
            ),
        child: Container(
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: effectiveOpacity),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDimmed ? 0.16 : 0.20),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      times?.$1 ?? '--:--',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      times?.$2 ?? '--:--',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '\u7b2c${slot.slot.startSection}-${slot.slot.endSection}\u8282',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            slot.slot.courseName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              decoration:
                                  isCancelled
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                              decorationColor: Colors.white.withValues(
                                alpha: 0.90,
                              ),
                              decorationThickness: 1.8,
                            ),
                          ),
                        ),
                        if (slot.overrideType != null)
                          _StatusBadge(type: slot.overrideType!),
                        if (slot.overrideType == null && !slot.isActive)
                          const _MutedBadge(label: '\u975e\u672c\u5468'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (slot.slot.location.isNotEmpty)
                      _MetaLine(
                        icon: Icons.place_outlined,
                        text: slot.slot.location,
                      ),
                    if (slot.teacher.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _MetaLine(
                        icon: Icons.person_outline_rounded,
                        text: slot.teacher,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.84)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ScheduleOverrideType type;

  const _StatusBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      ScheduleOverrideType.add => ('\u4e34\u65f6', const Color(0xFF5AA9FF)),
      ScheduleOverrideType.cancel => ('\u505c\u8bfe', const Color(0xFFFF6B6B)),
      ScheduleOverrideType.modify => (
        '\u5df2\u8c03\u6574',
        const Color(0xFFFF8A65),
      ),
    };

    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

class _MutedBadge extends StatelessWidget {
  final String label;

  const _MutedBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.92),
          height: 1,
        ),
      ),
    );
  }
}

Future<void> _openDailySlotMenu(
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
                '${_formatDate(date)} \u7b2c${slot.startSection}-${slot.endSection}\u8282',
              ),
            ),
            if (displaySlot.canMarkCancel)
              ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('\u672c\u6b21\u505c\u8bfe'),
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
                    const SnackBar(
                      content: Text(
                        '\u5df2\u6807\u8bb0\u672c\u6b21\u505c\u8bfe',
                      ),
                    ),
                  );
                },
              ),
            if (displaySlot.canAdjustOccurrence)
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: Text(
                  sourceOverride == null
                      ? '\u8c03\u6574\u672c\u6b21\u5b89\u6392'
                      : '\u7f16\u8f91\u4e34\u65f6\u5b89\u6392',
                ),
                onTap: () {
                  final editType =
                      sourceOverride?.type == ScheduleOverrideType.add
                          ? ScheduleOverrideType.add
                          : ScheduleOverrideType.modify;
                  Navigator.of(sheetContext).pop();
                  _openDailyOverrideForm(
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
                title: Text('\u672c\u5468\u4e0d\u5f00\u8bbe'),
                subtitle: Text(
                  '\u8fd9\u8282\u8bfe\u53ea\u662f\u4e3a\u4e86\u53c2\u8003\u663e\u793a\uff0c\u4e0d\u5bf9\u5e94\u672c\u5468\u5b9e\u9645\u8bfe\u6b21\uff0c\u6240\u4ee5\u4e0d\u80fd\u76f4\u63a5\u505c\u8bfe\u6216\u8c03\u6574\u3002',
                ),
              ),
            if (sourceOverride != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('\u5220\u9664\u4e34\u65f6\u8986\u76d6'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await provider.removeOverride(sourceOverride.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '\u5df2\u5220\u9664\u4e34\u65f6\u8986\u76d6',
                      ),
                    ),
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

Future<void> _openDailySlotDetails(
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
                                  '\u7b2c${slot.startSection}-${slot.endSection}\u8282',
                              icon: Icons.schedule_rounded,
                            ),
                            if (displaySlot.isReferenceOnly)
                              _buildChip(
                                context: sheetContext,
                                label: '\u975e\u672c\u5468\u53c2\u8003',
                                icon: Icons.visibility_outlined,
                                color: theme.colorScheme.outline,
                              ),
                            if (displaySlot.overrideType != null)
                              _buildChip(
                                context: sheetContext,
                                label: _overrideLabel(
                                  displaySlot.overrideType!,
                                ),
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
                label: '\u4e0a\u8bfe\u65f6\u95f4',
                value:
                    '\u7b2c${slot.startSection}-${slot.endSection}\u8282 ${times?.$1 ?? ''} - ${times?.$2 ?? ''}',
              ),
              _detailRow(
                icon: Icons.location_on_rounded,
                label: '\u4e0a\u8bfe\u5730\u70b9',
                value:
                    slot.location.isEmpty
                        ? '\u672a\u586b\u5199'
                        : slot.location,
              ),
              if (displaySlot.teacher.isNotEmpty)
                _detailRow(
                  icon: Icons.person_rounded,
                  label: '\u6388\u8bfe\u6559\u5e08',
                  value: displaySlot.teacher,
                ),
              if (sourceOverride?.note.trim().isNotEmpty == true)
                _detailRow(
                  icon: Icons.sticky_note_2_outlined,
                  label: '\u5907\u6ce8',
                  value: sourceOverride!.note.trim(),
                ),
              if (activeWeeks.isNotEmpty)
                _detailRow(
                  icon: Icons.date_range_rounded,
                  label: '\u5468\u6b21\u8303\u56f4',
                  value: _formatWeekList(activeWeeks),
                ),
              if (displaySlot.isReferenceOnly)
                _detailRow(
                  icon: Icons.info_outline_rounded,
                  label: '\u5f53\u524d\u72b6\u6001',
                  value:
                      '\u8fd9\u95e8\u8bfe\u5728\u7b2c$week\u5468\u4e0d\u5f00\u8bbe\uff0c\u8fd9\u91cc\u53ea\u662f\u53c2\u8003\u5c55\u793a\uff0c\u4e0d\u5bf9\u5e94\u672c\u5468\u5b9e\u9645\u8bfe\u6b21\u3002',
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
                        '\u539f\u5b89\u6392',
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
                          const SnackBar(
                            content: Text(
                              '\u5df2\u6807\u8bb0\u672c\u6b21\u505c\u8bfe',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.event_busy_outlined, size: 18),
                      label: const Text('\u672c\u6b21\u505c\u8bfe'),
                    ),
                  if (displaySlot.canAdjustOccurrence)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        final editType =
                            sourceOverride?.type == ScheduleOverrideType.add
                                ? ScheduleOverrideType.add
                                : ScheduleOverrideType.modify;
                        _openDailyOverrideForm(
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
                        sourceOverride == null
                            ? '\u8c03\u6574\u672c\u6b21\u5b89\u6392'
                            : '\u7f16\u8f91\u4e34\u65f6\u5b89\u6392',
                      ),
                    ),
                  if (sourceOverride != null)
                    TextButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await provider.removeOverride(sourceOverride.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '\u5df2\u5220\u9664\u4e34\u65f6\u8986\u76d6',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('\u5220\u9664\u4e34\u65f6\u8986\u76d6'),
                    ),
                  if (displaySlot.overrideType == ScheduleOverrideType.cancel)
                    Text(
                      '\u5f53\u524d\u5df2\u7ecf\u6807\u8bb0\u4e3a\u201c\u672c\u6b21\u505c\u8bfe\u201d\u3002\u5982\u679c\u4f60\u60f3\u6539\u6210\u8c03\u8bfe\uff0c\u8bf7\u5148\u5220\u9664\u8fd9\u6761\u505c\u8bfe\u5b89\u6392\uff0c\u518d\u91cd\u65b0\u521b\u5efa\u4e34\u65f6\u8c03\u6574\u3002',
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
                      '\u8fd9\u95e8\u8bfe\u5728\u672c\u5468\u5e76\u4e0d\u5f00\u8bbe\uff0c\u6240\u4ee5\u8fd9\u91cc\u6ca1\u6709\u201c\u672c\u6b21\u505c\u8bfe\u201d\u6216\u201c\u8c03\u6574\u672c\u6b21\u5b89\u6392\u201d\u7684\u5bf9\u8c61\u3002',
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

Future<void> _openDailyOverrideForm(
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
  final title =
      type == ScheduleOverrideType.add
          ? '\u65b0\u589e\u4e34\u65f6\u8bfe\u7a0b'
          : '\u8c03\u6574\u672c\u6b21\u5b89\u6392';
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
        builder: (context, setModalState) {
          if (startSection > totalSections) {
            startSection = totalSections;
          }
          if (endSection < startSection) {
            endSection = startSection;
          }
          if (endSection > totalSections) {
            endSection = totalSections;
          }

          final startItems = List.generate(totalSections, (index) => index + 1);
          final endItems = List.generate(
            totalSections - startSection + 1,
            (index) => startSection + index,
          );

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
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
                      '${_formatDate(date)} \u5468${WeekdayNames.getShort(weekday)}',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '\u8bfe\u7a0b\u540d\u79f0',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey(
                              'daily-start-$startSection-$endSection',
                            ),
                            initialValue: startSection,
                            decoration: const InputDecoration(
                              labelText: '\u5f00\u59cb\u8282\u6b21',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                startItems
                                    .map(
                                      (value) => DropdownMenuItem<int>(
                                        value: value,
                                        child: Text('\u7b2c$value\u8282'),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() {
                                startSection = value;
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
                            key: ValueKey(
                              'daily-end-$startSection-$endSection',
                            ),
                            initialValue: endSection,
                            decoration: const InputDecoration(
                              labelText: '\u7ed3\u675f\u8282\u6b21',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                endItems
                                    .map(
                                      (value) => DropdownMenuItem<int>(
                                        value: value,
                                        child: Text('\u7b2c$value\u8282'),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() => endSection = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: '\u5730\u70b9',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: teacherController,
                      decoration: const InputDecoration(
                        labelText: '\u6559\u5e08',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '\u5907\u6ce8',
                        hintText:
                            '\u4f8b\u5982\uff1a\u8c03\u5230\u5b9e\u9a8c\u697c\u3001\u548c\u67d0\u8bfe\u7a0b\u6362\u8bfe\u3001\u4e34\u65f6\u8865\u8bfe\u8bf4\u660e',
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '\u8bf7\u5148\u586b\u5199\u8bfe\u7a0b\u540d\u79f0',
                                ),
                              ),
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
                              context,
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
                                    ? '\u5df2\u6dfb\u52a0\u4e34\u65f6\u8bfe\u7a0b'
                                    : '\u5df2\u4fdd\u5b58\u4e34\u65f6\u8c03\u6574',
                              ),
                            ),
                          );
                        },
                        child: const Text('\u4fdd\u5b58'),
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

String _newOverrideId() {
  return DateTime.now().microsecondsSinceEpoch.toString();
}

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
      parts.add(start == end ? '$start\u5468' : '$start-$end\u5468');
      start = end = weeks[i];
    }
  }
  parts.add(start == end ? '$start\u5468' : '$start-$end\u5468');
  return parts.join('\uff0c');
}

String? _buildOriginalSummary(ScheduleOverride? override) {
  if (override == null || override.type == ScheduleOverrideType.add) {
    return null;
  }

  final pieces = <String>[];
  if (override.sourceCourseName.isNotEmpty) {
    pieces.add(override.sourceCourseName);
  }
  if (override.sourceStartSection != null &&
      override.sourceEndSection != null) {
    pieces.add(
      '\u7b2c${override.sourceStartSection}-${override.sourceEndSection}\u8282',
    );
  }
  if (override.sourceLocation.isNotEmpty) {
    pieces.add(override.sourceLocation);
  }
  if (override.sourceTeacher.isNotEmpty) {
    pieces.add(override.sourceTeacher);
  }
  return pieces.isEmpty ? null : pieces.join(' \u00b7 ');
}

String _overrideLabel(ScheduleOverrideType type) {
  switch (type) {
    case ScheduleOverrideType.add:
      return '\u4e34\u65f6\u52a0\u8bfe';
    case ScheduleOverrideType.cancel:
      return '\u672c\u6b21\u505c\u8bfe';
    case ScheduleOverrideType.modify:
      return '\u4e34\u65f6\u8c03\u6574';
  }
}

Color _overrideColor(ThemeData theme, ScheduleOverrideType type) {
  switch (type) {
    case ScheduleOverrideType.add:
      return theme.colorScheme.primary;
    case ScheduleOverrideType.cancel:
      return theme.colorScheme.error;
    case ScheduleOverrideType.modify:
      return const Color(0xFFB26A00);
  }
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
    if (displaySlot == null || !displaySlot.isActive) {
      continue;
    }

    final slot = displaySlot.slot;
    final sameSourceCourse =
        sourceSlot != null && slot.courseId == sourceSlot.courseId;
    final sameOverride =
        initialOverride != null &&
        displaySlot.sourceOverride?.id == initialOverride.id;

    if (sameSourceCourse || sameOverride) {
      continue;
    }

    conflicts.add(
      '${slot.courseName}\uff08\u7b2c${slot.startSection}-${slot.endSection}\u8282\uff09',
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
        title: const Text('\u53d1\u73b0\u65f6\u95f4\u51b2\u7a81'),
        content: Text(
          '\u76ee\u6807\u65f6\u6bb5\u5df2\u7ecf\u6709\u4ee5\u4e0b\u8bfe\u7a0b\u6216\u4e34\u65f6\u5b89\u6392\uff1a\n\n$summary\n\n\u4ecd\u7136\u7ee7\u7eed\u4fdd\u5b58\u5417\uff1f',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('\u4ecd\u7136\u4fdd\u5b58'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

String _weekdayLabel(int weekday) {
  const labels = <String>[
    '\u5468\u4e00',
    '\u5468\u4e8c',
    '\u5468\u4e09',
    '\u5468\u56db',
    '\u5468\u4e94',
    '\u5468\u516d',
    '\u5468\u65e5',
  ];
  return labels[(weekday - 1).clamp(0, 6)];
}
