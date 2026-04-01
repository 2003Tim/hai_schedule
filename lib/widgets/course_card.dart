import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../services/theme_provider.dart';
import '../utils/constants.dart';

class CourseCard extends StatelessWidget {
  final ScheduleSlot slot;
  final SchoolTimeConfig timeConfig;
  final double cellHeight;
  final bool isActive;
  final String teacher;
  final ScheduleOverrideType? overrideType;
  final bool isCurrentLesson;
  final bool isUpcomingLesson;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const CourseCard({
    super.key,
    required this.slot,
    required this.timeConfig,
    this.cellHeight = 58,
    this.isActive = true,
    this.teacher = '',
    this.overrideType,
    this.isCurrentLesson = false,
    this.isUpcomingLesson = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = CourseColors.getColor(slot.courseName);
    final height = slot.sectionSpan * cellHeight;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.read<ThemeProvider>();
    final cardOpacity = themeProvider.cardOpacity;
    final isCancelled = overrideType == ScheduleOverrideType.cancel;
    final isAdjusted = overrideType == ScheduleOverrideType.modify;
    final hasStatusBadge = isCancelled || isAdjusted;
    final isDimmedCard = !isActive;

    final activeOpacity = (cardOpacity * (isDark ? 0.92 : 0.95)).clamp(
      0.0,
      1.0,
    );

    final bgColor =
        isCancelled
            ? baseColor.withValues(alpha: isDark ? 0.24 : 0.28)
            : isAdjusted
            ? baseColor.withValues(alpha: isDark ? 0.28 : 0.32)
            : isDimmedCard
            ? baseColor.withValues(alpha: isDark ? 0.20 : 0.24)
            : baseColor.withValues(alpha: activeOpacity);

    const textColor = Colors.white;
    const subTextColor = Color(0xD6FFFFFF); // white @ 84%
    final highlightColor =
        isCurrentLesson
            ? const Color(0xFFFFD54F)
            : (isUpcomingLesson ? Colors.white.withValues(alpha: 0.92) : null);
    final borderColor =
        highlightColor ??
        (isDimmedCard
            ? Colors.white.withValues(alpha: isDark ? 0.18 : 0.22)
            : (isActive
                ? Colors.white.withValues(alpha: isDark ? 0.10 : 0.18)
                : baseColor.withValues(alpha: isDark ? 0.20 : 0.14)));

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1.5),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isCurrentLesson ? 2 : (isUpcomingLesson ? 1.4 : 1),
            ),
            boxShadow:
                isCurrentLesson
                    ? [
                      BoxShadow(
                        color: (highlightColor ?? baseColor).withValues(
                          alpha: 0.16,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : (isUpcomingLesson
                        ? [
                          BoxShadow(
                            color: baseColor.withValues(
                              alpha: isDark ? 0.08 : 0.10,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: 3,
                      child: Center(
                        child: Text(
                          slot.courseName,
                          style: TextStyle(
                            color: textColor,
                            fontSize: height > 100 ? 11 : 9.2,
                            fontWeight: FontWeight.w700,
                            height: 1.16,
                            decoration:
                                isCancelled
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                            decorationColor: Colors.white.withValues(
                              alpha: 0.92,
                            ),
                            decorationThickness: 1.8,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: height > 100 ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (slot.location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '@${_shortLocation(slot.location)}',
                          style: const TextStyle(
                            color: subTextColor,
                            fontSize: 9,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (teacher.isNotEmpty && height > 100)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _shortTeacher(teacher),
                          style: const TextStyle(
                            color: subTextColor,
                            fontSize: 9,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasStatusBadge)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _overrideBadgeColor(overrideType!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _overrideLabel(overrideType!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isCurrentLesson || isUpcomingLesson)
                Positioned(
                  top: 0,
                  left: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isCurrentLesson ? 0.22 : 0.16,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isCurrentLesson ? '进行中' : '下一节',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortLocation(String location) {
    return location.replaceAll(RegExp(r'\(.*?\)'), '').trim();
  }

  String _shortTeacher(String value) {
    if (value.contains(',')) return value.split(',').first;
    if (value.contains('，')) return value.split('，').first;
    return value;
  }

  String _overrideLabel(ScheduleOverrideType type) {
    switch (type) {
      case ScheduleOverrideType.add:
        return '临时';
      case ScheduleOverrideType.cancel:
        return '停课';
      case ScheduleOverrideType.modify:
        return '已调整';
    }
  }

  Color _overrideBadgeColor(ScheduleOverrideType type) {
    switch (type) {
      case ScheduleOverrideType.add:
        return const Color(0xFF5AA9FF);
      case ScheduleOverrideType.cancel:
        return const Color(0xFFFF6B6B);
      case ScheduleOverrideType.modify:
        return const Color(0xFFFF8A65);
    }
  }
}
