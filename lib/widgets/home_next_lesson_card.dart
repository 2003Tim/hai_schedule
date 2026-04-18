import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/services/class_reminder_service.dart';
import 'package:hai_schedule/services/class_silence_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/utils/constants.dart';

class HomeNextLessonCard extends StatefulWidget {
  HomeNextLessonCard({super.key, DateTime Function()? nowFactory})
    : nowFactory = nowFactory ?? DateTime.now;

  final DateTime Function() nowFactory;

  @override
  State<HomeNextLessonCard> createState() => _HomeNextLessonCardState();
}

class _HomeNextLessonCardState extends State<HomeNextLessonCard>
    with WidgetsBindingObserver {
  ReminderSnapshot? _reminderSnapshot;
  ClassSilenceSnapshot? _silenceSnapshot;
  Timer? _minuteStarterTimer;
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _scheduleMinuteTimer();
  }

  void _scheduleMinuteTimer() {
    _minuteStarterTimer?.cancel();
    _minuteTimer?.cancel();
    final now = widget.nowFactory();
    final msUntilNextMinute = (60 - now.second) * 1000 - now.millisecond;
    _minuteStarterTimer = Timer(Duration(milliseconds: msUntilNextMinute), () {
      if (!mounted) return;
      setState(() {});
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _minuteStarterTimer?.cancel();
    _minuteTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final reminder = await ClassReminderService.loadSnapshot();
    final silence = await ClassSilenceService.loadSnapshot();
    if (!mounted) return;
    setState(() {
      _reminderSnapshot = reminder;
      _silenceSnapshot = silence;
    });
  }

  _NextLessonInfo? _computeNextLesson(ScheduleProvider provider) {
    final now = widget.nowFactory();
    final nowDate = DateTime(now.year, now.month, now.day);
    final nowMinutes = now.hour * 60 + now.minute;
    final currentWeek = provider.weekCalc.getWeekNumber(now);
    final timeConfig = provider.timeConfig;
    if (currentWeek > provider.weekCalc.totalWeeks) return null;

    final startWeek = currentWeek < 1 ? 1 : currentWeek;
    final startWeekday = currentWeek < 1 ? 1 : now.weekday;

    for (var week = startWeek; week <= provider.weekCalc.totalWeeks; week++) {
      final dayStart = week == startWeek ? startWeekday : 1;
      for (var weekday = dayStart; weekday <= DateTime.daysPerWeek; weekday++) {
        final slots =
            provider
                .getDisplaySlotsForDay(week, weekday)
                .where(
                  (slot) =>
                      slot.isActive &&
                      slot.overrideType != ScheduleOverrideType.cancel,
                )
                .toList();
        if (slots.isEmpty) continue;

        final lessonDate = provider.getDateForSlot(week, weekday);
        final isToday =
            currentWeek >= 1 &&
            week == currentWeek &&
            weekday == now.weekday &&
            _isSameDate(lessonDate, nowDate);

        for (final slot in slots) {
          final start = timeConfig.getClassTime(slot.slot.startSection);
          final end = timeConfig.getClassTime(slot.slot.endSection);
          if (start == null || end == null) continue;
          if (isToday && end.endMinutes < nowMinutes) {
            continue;
          }

          final isOngoing =
              isToday &&
              nowMinutes >= start.startMinutes &&
              nowMinutes <= end.endMinutes;
          return _buildLessonInfo(
            slot: slot,
            lessonDate: lessonDate,
            nowDate: nowDate,
            nowMinutes: nowMinutes,
            isOngoing: isOngoing,
            timeConfig: timeConfig,
          );
        }
      }
    }

    return null;
  }

  _NextLessonInfo _buildLessonInfo({
    required DisplayScheduleSlot slot,
    required DateTime lessonDate,
    required DateTime nowDate,
    required int nowMinutes,
    required bool isOngoing,
    required SchoolTimeConfig timeConfig,
  }) {
    final startTime = timeConfig.getClassTime(slot.slot.startSection);
    final endTime = timeConfig.getClassTime(slot.slot.endSection);
    final startText = startTime?.startTime ?? '';
    final endText = endTime?.endTime ?? '';
    final timeText =
        (startText.isNotEmpty && endText.isNotEmpty)
            ? '$startText - $endText'
            : '';

    String label;
    if (isOngoing) {
      label = '进行中';
    } else if (_isSameDate(lessonDate, nowDate)) {
      final start = timeConfig.getClassTime(slot.slot.startSection)!;
      final diffMin = start.startMinutes - nowMinutes;
      if (diffMin <= 60) {
        label = '$diffMin 分钟后';
      } else {
        final h = diffMin ~/ 60;
        final m = diffMin % 60;
        label = m == 0 ? '$h 小时后' : '$h 时 $m 分后';
      }
    } else {
      label = _relativeDayLabel(nowDate, lessonDate);
    }

    return _NextLessonInfo(
      slot: slot.slot,
      teacher: slot.teacher,
      label: label,
      timeText: timeText,
      startText: startText,
      endText: endText,
      dateText:
          _isSameDate(lessonDate, nowDate)
              ? ''
              : '${_weekdayLabel(lessonDate.weekday)} · ${lessonDate.month}/${lessonDate.day}',
      isOngoing: isOngoing,
    );
  }

  bool _isSameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _relativeDayLabel(DateTime nowDate, DateTime lessonDate) {
    final diffDays = lessonDate.difference(nowDate).inDays;
    if (diffDays <= 0) return '稍后';
    if (diffDays == 1) return '明天';
    if (diffDays == 2) return '后天';
    return '$diffDays 天后';
  }

  String _weekdayLabel(int weekday) {
    const labels = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  Widget _buildStatusIcon({required IconData icon, required Color baseColor}) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.34),
          width: 0.5,
        ),
      ),
      child: Icon(icon, size: 11, color: baseColor.withValues(alpha: 0.88)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final info = _computeNextLesson(provider);
    if (info == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final baseColor = CourseColors.getColor(info.slot.courseName);
    final onSurfaceColor = theme.colorScheme.onSurface;

    final reminderEnabled = _reminderSnapshot?.settings.enabled == true;
    final silenceEnabled =
        _silenceSnapshot?.settings.enabled == true &&
        _silenceSnapshot?.policyAccessGranted == true;
    final sectionText = '第${info.slot.startSection}-${info.slot.endSection}节';
    final primaryMeta = [
      sectionText,
      if (info.timeText.isNotEmpty) info.timeText,
    ].join(' · ');
    final secondaryMeta = [
      if (info.slot.location.isNotEmpty) '@${info.slot.location}',
      if (info.teacher.isNotEmpty) info.teacher,
    ].join(' · ');
    final countdownText = info.label;
    final timeText =
        info.isOngoing && info.endText.isNotEmpty
            ? '至 ${info.endText}'
            : (info.startText.isNotEmpty ? info.startText : '--:--');

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 320;
          final horizontalGap = isCompact ? 10.0 : 14.0;
          final indicatorHeight = isCompact ? 20.0 : 24.0;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                info.slot.courseName,
                maxLines: isCompact ? 3 : 2,
                softWrap: true,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontSize: isCompact ? 13 : 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.22,
                  color: onSurfaceColor.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                primaryMeta,
                maxLines: isCompact ? 2 : 1,
                overflow: TextOverflow.fade,
                softWrap: true,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: onSurfaceColor.withValues(alpha: 0.72),
                ),
              ),
              if (info.dateText.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  info.dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceColor.withValues(alpha: 0.68),
                  ),
                ),
              ],
              if (secondaryMeta.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  secondaryMeta,
                  maxLines: isCompact ? 3 : 2,
                  softWrap: true,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    color: onSurfaceColor.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ],
          );

          final trailing = Column(
            crossAxisAlignment:
                isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                countdownText,
                textAlign: isCompact ? TextAlign.left : TextAlign.right,
                maxLines: isCompact ? 3 : 2,
                softWrap: true,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  color: baseColor.withValues(alpha: 0.96),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeText,
                textAlign: isCompact ? TextAlign.left : TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: onSurfaceColor.withValues(alpha: 0.62),
                ),
              ),
              if (reminderEnabled || silenceEnabled) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (reminderEnabled)
                      _buildStatusIcon(
                        icon: Icons.notifications_active_rounded,
                        baseColor: baseColor,
                      ),
                    if (reminderEnabled && silenceEnabled)
                      const SizedBox(width: 4),
                    if (silenceEnabled)
                      _buildStatusIcon(
                        icon: Icons.volume_off_rounded,
                        baseColor: baseColor,
                      ),
                  ],
                ),
              ],
            ],
          );

          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 0.5,
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              isCompact ? 12 : 14,
              9,
              isCompact ? 12 : 14,
              9,
            ),
            child:
                isCompact
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: indicatorHeight,
                              margin: const EdgeInsets.only(top: 3),
                              decoration: BoxDecoration(
                                color: baseColor.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: details),
                          ],
                        ),
                        const SizedBox(height: 8),
                        trailing,
                      ],
                    )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 3,
                          height: indicatorHeight,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: baseColor.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: details),
                        SizedBox(width: horizontalGap),
                        Flexible(child: trailing),
                      ],
                    ),
          );
        },
      ),
    );
  }
}

class _NextLessonInfo {
  const _NextLessonInfo({
    required this.slot,
    required this.teacher,
    required this.label,
    required this.timeText,
    required this.startText,
    required this.endText,
    required this.dateText,
    this.isOngoing = false,
  });

  final ScheduleSlot slot;
  final String teacher;
  final String label;
  final String timeText;
  final String startText;
  final String endText;
  final String dateText;
  final bool isOngoing;
}
