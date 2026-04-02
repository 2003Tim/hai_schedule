import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../services/schedule_provider.dart';
import '../services/theme_provider.dart';
import '../utils/constants.dart';

class DailyHeaderCard extends StatelessWidget {
  const DailyHeaderCard({
    super.key,
    required this.weekdayLabel,
    required this.count,
    required this.onAddPressed,
  });

  final String weekdayLabel;
  final int count;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final subtitle = count == 0 ? '今天暂时没有课程安排' : '今天有 $count 节课，加油！';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                weekdayLabel,
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
                '$count 节安排',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: '新增临时安排',
              child: IconButton(
                onPressed: onAddPressed,
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

class DailyLessonCard extends StatelessWidget {
  const DailyLessonCard({
    super.key,
    required this.slot,
    required this.timeConfig,
    required this.onTap,
    required this.onLongPress,
  });

  final DisplayScheduleSlot slot;
  final SchoolTimeConfig timeConfig;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
        onTap: onTap,
        onLongPress: onLongPress,
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
                        '第${slot.slot.startSection}-${slot.slot.endSection}节',
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
                          const _MutedBadge(label: '非本周'),
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
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

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
  const _StatusBadge({required this.type});

  final ScheduleOverrideType type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      ScheduleOverrideType.add => ('临时', const Color(0xFF5AA9FF)),
      ScheduleOverrideType.cancel => ('停课', const Color(0xFFFF6B6B)),
      ScheduleOverrideType.modify => ('已调整', const Color(0xFFFF8A65)),
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
  const _MutedBadge({required this.label});

  final String label;

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
