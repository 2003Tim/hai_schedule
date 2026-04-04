import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/utils/semester_code_formatter.dart';

class ScheduleOverridesScreen extends StatelessWidget {
  const ScheduleOverridesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final overrides = [...provider.overrides]..sort((a, b) {
      final dateCompare = a.dateKey.compareTo(b.dateKey);
      if (dateCompare != 0) return dateCompare;
      final sectionCompare = a.startSection.compareTo(b.startSection);
      if (sectionCompare != 0) return sectionCompare;
      return a.type.index.compareTo(b.type.index);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('\u4e34\u65f6\u5b89\u6392'),
        centerTitle: true,
      ),
      body:
          overrides.isEmpty
              ? _EmptyState(semesterCode: provider.currentSemesterCode)
              : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: _buildSections(context, provider, overrides),
              ),
    );
  }

  List<Widget> _buildSections(
    BuildContext context,
    ScheduleProvider provider,
    List<ScheduleOverride> overrides,
  ) {
    final grouped = <String, List<ScheduleOverride>>{};
    for (final item in overrides) {
      grouped.putIfAbsent(item.dateKey, () => <ScheduleOverride>[]).add(item);
    }

    final entries =
        grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return [
      for (final entry in entries) ...[
        _DateHeader(
          dateKey: entry.key,
          weekNumber: provider.weekCalc.getWeekNumber(_parseDateKey(entry.key)),
        ),
        const SizedBox(height: 8),
        ...entry.value.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OverrideCard(item: item),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  static DateTime _parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return DateTime.now();
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final day = int.tryParse(parts[2]) ?? DateTime.now().day;
    return DateTime(year, month, day);
  }
}

class _EmptyState extends StatelessWidget {
  final String? semesterCode;

  const _EmptyState({required this.semesterCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 44,
              color: theme.colorScheme.primary.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 12),
            const Text(
              '\u5f53\u524d\u5b66\u671f\u8fd8\u6ca1\u6709\u4e34\u65f6\u5b89\u6392',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '\u53ef\u4ee5\u5728\u9996\u9875\u957f\u6309\u8bfe\u8868\u683c\u5b50\uff0c\u65b0\u589e\u4e34\u65f6\u52a0\u8bfe\u3001\u505c\u8bfe\u6216\u8c03\u8bfe\u3002',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            if (semesterCode != null && semesterCode!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  '\u5f53\u524d\u5b66\u671f\uff1a${_formatSemesterCode(semesterCode!)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String dateKey;
  final int weekNumber;

  const _DateHeader({required this.dateKey, required this.weekNumber});

  @override
  Widget build(BuildContext context) {
    final date = ScheduleOverridesScreen._parseDateKey(dateKey);
    final theme = Theme.of(context);
    const weekdayNames = <String>[
      '\u5468\u4e00',
      '\u5468\u4e8c',
      '\u5468\u4e09',
      '\u5468\u56db',
      '\u5468\u4e94',
      '\u5468\u516d',
      '\u5468\u65e5',
    ];
    final weekdayIndex = date.weekday - 1;

    return Row(
      children: [
        Text(
          '${date.month}\u6708${date.day}\u65e5 ${weekdayNames[weekdayIndex]}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            weekNumber > 0
                ? '\u7b2c $weekNumber \u5468'
                : '\u5b66\u671f\u8303\u56f4\u5916',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverrideCard extends StatelessWidget {
  final ScheduleOverride item;

  const _OverrideCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ScheduleProvider>();
    final theme = Theme.of(context);
    final date = ScheduleOverridesScreen._parseDateKey(item.dateKey);
    final week = provider.weekCalc.getWeekNumber(date);
    final canJump = week >= 1 && week <= provider.weekCalc.totalWeeks;
    final detail = _detailText(item);
    final needsReview = item.status == ScheduleOverrideStatus.orphaned;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: _typeColor(context, item.type).withValues(alpha: 0.18),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap:
            canJump
                ? () {
                  provider.selectWeek(week);
                  Navigator.of(context).pop();
                }
                : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _typeColor(context, item.type).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _typeLabel(item.type),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _typeColor(context, item.type),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(item),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\u7b2c ${item.startSection}-${item.endSection} \u8282',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                    ],
                    if (needsReview) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.error.withValues(
                              alpha: 0.22,
                            ),
                          ),
                        ),
                        child: Text(
                          '\u9700\u68c0\u67e5\uff1a\u540c\u6b65\u540e\u539f\u8bfe\u53ef\u80fd\u5df2\u53d8\u5316\uff0c\u8fd9\u6761\u4e34\u65f6\u5b89\u6392\u53ef\u80fd\u5df2\u5931\u6548',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (canJump) ...[
                      const SizedBox(height: 8),
                      Text(
                        '\u70b9\u6309\u53ef\u8df3\u8f6c\u5230\u5bf9\u5e94\u5468\u6b21',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.82,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '\u5220\u9664\u4e34\u65f6\u5b89\u6392',
                onPressed: () => _confirmDelete(context),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<ScheduleProvider>();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('\u5220\u9664\u4e34\u65f6\u5b89\u6392'),
              content: Text(
                '\u786e\u8ba4\u5220\u9664\u201c${_title(item)}\u201d\u5417\uff1f',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('\u53d6\u6d88'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('\u5220\u9664'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) return;

    await provider.removeOverride(item.id);
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('\u5df2\u5220\u9664\u4e34\u65f6\u5b89\u6392'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _title(ScheduleOverride item) {
    final fallback = switch (item.type) {
      ScheduleOverrideType.add => '\u4e34\u65f6\u8bfe\u7a0b',
      ScheduleOverrideType.cancel => '\u505c\u8bfe\u5b89\u6392',
      ScheduleOverrideType.modify => '\u8c03\u8bfe\u5b89\u6392',
    };
    return item.courseName.trim().isEmpty ? fallback : item.courseName.trim();
  }

  static String _detailText(ScheduleOverride item) {
    final segments = <String>[];
    if (item.teacher.trim().isNotEmpty) segments.add(item.teacher.trim());
    if (item.location.trim().isNotEmpty) segments.add(item.location.trim());
    if (item.note.trim().isNotEmpty) segments.add(item.note.trim());
    return segments.join(' \u00b7 ');
  }

  static String _typeLabel(ScheduleOverrideType type) {
    return switch (type) {
      ScheduleOverrideType.add => '\u4e34\u65f6\u52a0\u8bfe',
      ScheduleOverrideType.cancel => '\u672c\u6b21\u505c\u8bfe',
      ScheduleOverrideType.modify => '\u4e34\u65f6\u8c03\u6574',
    };
  }

  static Color _typeColor(BuildContext context, ScheduleOverrideType type) {
    final scheme = Theme.of(context).colorScheme;
    return switch (type) {
      ScheduleOverrideType.add => scheme.primary,
      ScheduleOverrideType.cancel => scheme.error,
      ScheduleOverrideType.modify => const Color(0xFFB26A00),
    };
  }
}

String _formatSemesterCode(String code) => formatSemesterCode(code);
/*
  if (code.length < 5) return code;
  final startYear = code.substring(0, 4);
  final endYear = (int.tryParse(startYear) ?? 0) + 1;
  final term = code.substring(4) == '1'
      ? '\u7b2c\u4e00\u5b66\u671f'
      : '\u7b2c\u4e8c\u5b66\u671f';
  return '$startYear-$endYear $term';
}
*/
