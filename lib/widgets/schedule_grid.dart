import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../services/schedule_provider.dart';
import '../services/theme_provider.dart';
import '../utils/constants.dart';
import 'course_card.dart';
import 'schedule_slot_dialogs.dart';

class ScheduleGrid extends StatelessWidget {
  final ScheduleProvider provider;
  final int? weekOverride;

  const ScheduleGrid({super.key, required this.provider, this.weekOverride});

  static const double _headerHeight = 60;
  static const double _timeColWidth = 40;
  static const double _cellHeight = 58;
  static const double _periodGap = 10;
  static const double _dayColumnHorizontalInset = 3;

  static const int _statusNone = 0;
  static const int _statusCurrent = 1;
  static const int _statusUpcoming = 2;

  @override
  Widget build(BuildContext context) {
    final week = weekOverride ?? provider.selectedWeek;
    final days = provider.displayDays;
    final timeConfig = provider.timeConfig;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: Column(
          children: [
            _buildDayHeader(context, week, days),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RepaintBoundary(
                      child: _buildTimeColumn(context, timeConfig),
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: _buildGrid(context, week, days, timeConfig),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, int week, int days) {
    final today = provider.todayWeekday;
    final isCurrentWeek = week == provider.currentWeek;
    final theme = Theme.of(context);
    final themeProvider = context.read<ThemeProvider>();
    final isLightTheme = theme.brightness == Brightness.light;
    final primaryTextColor =
        isLightTheme ? theme.colorScheme.onSurface : Colors.white;
    final secondaryTextColor =
        isLightTheme
            ? theme.colorScheme.onSurface.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.84);
    final fillTop = themeProvider.glassPanelStrongFill(
      theme.brightness,
      strength: 0.76,
    );
    final fillBottom = themeProvider.glassPanelFill(
      theme.brightness,
      strength: 0.66,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fillTop, fillBottom],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: themeProvider.glassOutline(theme.brightness, strength: 0.82),
        ),
      ),
      child: SizedBox(
        height: _headerHeight,
        child: Row(
          children: [
            SizedBox(
              width: _timeColWidth,
              child: Center(
                child: Text(
                  '${provider.weekCalc.getWeekMonday(week).month}\n月',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: primaryTextColor,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            ...List.generate(days, (i) {
              final weekday = i + 1;
              final date = provider.weekCalc.getDate(week, weekday);
              final isToday = isCurrentWeek && weekday == today;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _dayColumnHorizontalInset,
                    vertical: 6,
                  ),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration:
                          isToday
                              ? BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha:
                                      theme.brightness == Brightness.dark
                                          ? 0.18
                                          : 0.10,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha:
                                        theme.brightness == Brightness.dark
                                            ? 0.08
                                            : 0.16,
                                  ),
                                ),
                              )
                              : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Text(
                              WeekdayNames.getShort(weekday),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    isToday ? FontWeight.w700 : FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration:
                                  isToday
                                      ? BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.colorScheme.primary
                                                .withValues(alpha: 0.92),
                                            theme.colorScheme.primary
                                                .withValues(alpha: 0.76),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      )
                                      : null,
                              child: Text(
                                '${date.day}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isToday ? Colors.white : primaryTextColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeColumn(BuildContext context, SchoolTimeConfig config) {
    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;
    final primaryTextColor =
        isLightTheme ? theme.colorScheme.onSurface : Colors.white;
    final secondaryTextColor =
        isLightTheme
            ? theme.colorScheme.onSurface.withValues(alpha: 0.70)
            : Colors.white.withValues(alpha: 0.70);
    final children = <Widget>[];

    for (final period in TimePeriod.values) {
      children.add(
        Container(
          height: 18,
          alignment: Alignment.center,
          child: Text(
            period.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor,
              letterSpacing: 2,
            ),
          ),
        ),
      );

      for (int s = period.startSection; s <= period.endSection; s++) {
        if (s > config.totalSections) break;
        final ct = config.getClassTime(s)!;
        children.add(
          GestureDetector(
            onLongPress:
                () =>
                    _openSectionTimeEditor(context, section: s, classTime: ct),
            child: SizedBox(
              height: _cellHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$s',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${ct.startTime}\n${ct.endTime}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 7.2,
                      height: 1.2,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (period != TimePeriod.evening) {
        children.add(const SizedBox(height: _periodGap));
      }
    }

    return SizedBox(width: _timeColWidth, child: Column(children: children));
  }

  Widget _buildGrid(
    BuildContext context,
    int week,
    int days,
    SchoolTimeConfig timeConfig,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(days, (dayIndex) {
        final weekday = dayIndex + 1;
        return Expanded(
          child: RepaintBoundary(
            child: _buildDayColumn(context, week, weekday, timeConfig),
          ),
        );
      }),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    int week,
    int weekday,
    SchoolTimeConfig timeConfig,
  ) {
    final children = <Widget>[];

    for (final period in TimePeriod.values) {
      children.add(const SizedBox(height: 18));

      int section = period.startSection;
      while (section <= period.endSection &&
          section <= timeConfig.totalSections) {
        final displaySlot = provider.getDisplaySlotAt(week, weekday, section);

        if (displaySlot != null && displaySlot.slot.startSection == section) {
          final lessonStatus = _lessonStatusForSlot(
            week: week,
            weekday: weekday,
            slot: displaySlot.slot,
          );
          children.add(
            CourseCard(
              slot: displaySlot.slot,
              timeConfig: timeConfig,
              cellHeight: _cellHeight,
              isActive: displaySlot.isActive,
              teacher: displaySlot.teacher,
              overrideType: displaySlot.overrideType,
              isCurrentLesson: lessonStatus == _statusCurrent,
              isUpcomingLesson: lessonStatus == _statusUpcoming,
              onTap: () => openScheduleSlotDetails(
                context,
                provider: provider,
                week: week,
                weekday: weekday,
                displaySlot: displaySlot,
              ),
              onLongPress: () => openScheduleSlotMenu(
                context,
                provider: provider,
                week: week,
                weekday: weekday,
                displaySlot: displaySlot,
              ),
            ),
          );
          section = displaySlot.slot.endSection + 1;
          continue;
        }

        final targetSection = section;
        children.add(
          _EmptyScheduleCell(
            height: _cellHeight,
            onLongPress: () => openScheduleOverrideForm(
              context,
              provider: provider,
              week: week,
              weekday: weekday,
              type: ScheduleOverrideType.add,
              initialStartSection: targetSection,
              initialEndSection: targetSection,
            ),
          ),
        );
        section++;
      }

      if (period != TimePeriod.evening) {
        children.add(const SizedBox(height: _periodGap));
      }
    }

    return Column(children: children);
  }

  Future<void> _openSectionTimeEditor(
    BuildContext context, {
    required int section,
    required ClassTime classTime,
  }) async {
    final start = await _pickTime(
      context,
      initial: classTime.startTime,
      title: '选择第$section节开始时间',
    );
    if (start == null || !context.mounted) return;

    final end = await _pickTime(
      context,
      initial: classTime.endTime,
      title: '选择第$section节结束时间',
    );
    if (end == null || !context.mounted) return;

    final startMinutes = _timeToMinutes(start);
    final endMinutes = _timeToMinutes(end);
    if (startMinutes == null ||
        endMinutes == null ||
        startMinutes >= endMinutes) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('开始时间必须早于结束时间')));
      return;
    }

    final updated =
        provider.timeConfig.classTimes.map((item) => item.copyWith()).toList();
    updated[section - 1] = updated[section - 1].copyWith(
      startTime: start,
      endTime: end,
    );

    if (!_validateClassTimes(updated)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该节时间会与相邻节次重叠，请重新调整')));
      return;
    }

    await provider.updateTimeConfig(
      provider.timeConfig.copyWith(classTimes: updated),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('第$section节时间已更新')));
  }

  Future<String?> _pickTime(
    BuildContext context, {
    required String initial,
    required String title,
  }) async {
    final parts = initial.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: int.tryParse(parts.last) ?? 0,
      ),
      helpText: title,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return null;
    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _validateClassTimes(List<ClassTime> classTimes) {
    for (var index = 0; index < classTimes.length; index++) {
      final current = classTimes[index];
      if (current.startMinutes >= current.endMinutes) {
        return false;
      }
      if (index > 0) {
        final previous = classTimes[index - 1];
        if (current.startMinutes < previous.endMinutes) {
          return false;
        }
      }
    }
    return true;
  }

  int _lessonStatusForSlot({
    required int week,
    required int weekday,
    required ScheduleSlot slot,
  }) {
    final displayAtStart = provider.getDisplaySlotAt(
      week,
      weekday,
      slot.startSection,
    );
    if (displayAtStart == null || !displayAtStart.isActive) {
      return _statusNone;
    }
    if (week != provider.currentWeek || weekday != provider.todayWeekday) {
      return _statusNone;
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final times = provider.timeConfig.getSlotTime(
      slot.startSection,
      slot.endSection,
    );
    final startMinutes = _timeToMinutes(times?.$1);
    final endMinutes = _timeToMinutes(times?.$2);
    if (startMinutes == null || endMinutes == null) return _statusNone;

    if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
      return _statusCurrent;
    }

    if (currentMinutes >= startMinutes) {
      return _statusNone;
    }

    for (
      var section = 1;
      section <= provider.timeConfig.totalSections;
      section++
    ) {
      final displaySlot = provider.getDisplaySlotAt(week, weekday, section);
      if (displaySlot == null || !displaySlot.isActive) continue;
      if (displaySlot.slot.startSection != section) continue;

      final candidateTimes = provider.timeConfig.getSlotTime(
        displaySlot.slot.startSection,
        displaySlot.slot.endSection,
      );
      final candidateStart = _timeToMinutes(candidateTimes?.$1);
      if (candidateStart == null || candidateStart < currentMinutes) continue;

      return displaySlot.slot.courseId == slot.courseId &&
              displaySlot.slot.startSection == slot.startSection &&
              displaySlot.slot.endSection == slot.endSection
          ? _statusUpcoming
          : _statusNone;
    }

    return _statusNone;
  }

  int? _timeToMinutes(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

}

class _EmptyScheduleCell extends StatelessWidget {
  final double height;
  final VoidCallback onLongPress;

  const _EmptyScheduleCell({required this.height, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
