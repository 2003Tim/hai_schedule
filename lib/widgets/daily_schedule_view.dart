import 'package:flutter/material.dart';

import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/widgets/daily_schedule_cards.dart';
import 'package:hai_schedule/widgets/schedule_slot_dialogs.dart';

class DailyScheduleView extends StatelessWidget {
  const DailyScheduleView({
    super.key,
    required this.provider,
    required this.week,
    required this.weekday,
  });

  final ScheduleProvider provider;
  final int week;
  final int weekday;

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
                '这一天没有课程安排',
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
                    () => openScheduleOverrideForm(
                      context,
                      provider: provider,
                      week: week,
                      weekday: weekday,
                      type: ScheduleOverrideType.add,
                    ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新增临时安排'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
      itemCount: entries.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return DailyHeaderCard(
            weekdayLabel: _weekdayLabel(weekday),
            dateLabel: '${date.month}/${date.day}',
            subtitle: _headerSubtitle(date, entries.length),
            count: entries.length,
            onAddPressed:
                () => openScheduleOverrideForm(
                  context,
                  provider: provider,
                  week: week,
                  weekday: weekday,
                  type: ScheduleOverrideType.add,
                ),
          );
        }

        final entry = entries[index - 1];
        return DailyLessonCard(
          slot: entry,
          timeConfig: provider.timeConfig,
          onTap:
              () => openScheduleSlotDetails(
                context,
                provider: provider,
                week: week,
                weekday: weekday,
                displaySlot: entry,
              ),
          onLongPress:
              () => openScheduleSlotMenu(
                context,
                provider: provider,
                week: week,
                weekday: weekday,
                displaySlot: entry,
              ),
        );
      },
    );
  }
}

String _headerSubtitle(DateTime date, int count) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final targetDate = DateTime(date.year, date.month, date.day);
  final diffDays = targetDate.difference(todayDate).inDays;
  final prefix = switch (diffDays) {
    0 => '今天',
    1 => '明天',
    -1 => '昨天',
    _ => '这一天',
  };

  if (count == 0) {
    return prefix == '今天' ? '今天暂时没有课程安排' : '$prefix没有课程安排';
  }
  if (prefix == '今天') {
    return '今天有 $count 节课，加油！';
  }
  if (prefix == '明天') {
    return '明天有 $count 节课，提前做好准备';
  }
  return '$prefix有 $count 节课，记得留意时间';
}

String _weekdayLabel(int weekday) {
  const labels = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return labels[(weekday - 1).clamp(0, 6)];
}
