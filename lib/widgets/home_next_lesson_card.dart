import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../services/class_reminder_service.dart';
import '../services/class_silence_service.dart';
import '../services/schedule_provider.dart';
import '../utils/constants.dart';

class HomeNextLessonCard extends StatefulWidget {
  const HomeNextLessonCard({super.key});

  @override
  State<HomeNextLessonCard> createState() => _HomeNextLessonCardState();
}

class _HomeNextLessonCardState extends State<HomeNextLessonCard>
    with WidgetsBindingObserver {
  ReminderSnapshot? _reminderSnapshot;
  ClassSilenceSnapshot? _silenceSnapshot;
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _scheduleMinuteTimer();
  }

  void _scheduleMinuteTimer() {
    final now = DateTime.now();
    final msUntilNextMinute = (60 - now.second) * 1000 - now.millisecond;
    Future.delayed(Duration(milliseconds: msUntilNextMinute), () {
      if (!mounted) return;
      setState(() {});
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
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
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final todayWeekday = provider.todayWeekday;
    final currentWeek = provider.currentWeek;
    final timeConfig = provider.timeConfig;

    final slots =
        provider
            .getDisplaySlotsForDay(currentWeek, todayWeekday)
            .where(
              (d) =>
                  d.isActive && d.overrideType != ScheduleOverrideType.cancel,
            )
            .toList();
    if (slots.isEmpty) return null;

    DisplayScheduleSlot? found;
    var isOngoing = false;

    for (final d in slots) {
      final start = timeConfig.getClassTime(d.slot.startSection);
      final end = timeConfig.getClassTime(d.slot.endSection);
      if (start == null || end == null) continue;
      if (nowMinutes >= start.startMinutes && nowMinutes <= end.endMinutes) {
        found = d;
        isOngoing = true;
        break;
      }
    }

    if (!isOngoing) {
      DisplayScheduleSlot? earliest;
      int? earliestStart;
      for (final d in slots) {
        final start = timeConfig.getClassTime(d.slot.startSection);
        if (start == null) continue;
        if (start.startMinutes > nowMinutes) {
          if (earliestStart == null || start.startMinutes < earliestStart) {
            earliestStart = start.startMinutes;
            earliest = d;
          }
        }
      }
      if (earliest == null) return null;
      found = earliest;
    }

    if (found == null) return null;

    final startTime = timeConfig.getClassTime(found.slot.startSection);
    final endTime = timeConfig.getClassTime(found.slot.endSection);
    final startText = startTime?.startTime ?? '';
    final endText = endTime?.endTime ?? '';
    final timeText =
        (startText.isNotEmpty && endText.isNotEmpty)
            ? '$startText - $endText'
            : '';

    String label;
    if (isOngoing) {
      label = '进行中';
    } else {
      final start = timeConfig.getClassTime(found.slot.startSection)!;
      final diffMin = start.startMinutes - nowMinutes;
      if (diffMin <= 60) {
        label = '$diffMin 分钟后';
      } else {
        final h = diffMin ~/ 60;
        final m = diffMin % 60;
        label = m == 0 ? '$h 小时后' : '$h 时 $m 分后';
      }
    }

    return _NextLessonInfo(
      slot: found.slot,
      teacher: found.teacher,
      label: label,
      timeText: timeText,
      startText: startText,
      endText: endText,
      isOngoing: isOngoing,
    );
  }

  Widget _buildStatusIcon({
    required IconData icon,
    required Color baseColor,
  }) {
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
    this.isOngoing = false,
  });

  final ScheduleSlot slot;
  final String teacher;
  final String label;
  final String timeText;
  final String startText;
  final String endText;
  final bool isOngoing;
}
