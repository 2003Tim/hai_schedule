import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/services/class_reminder_service.dart';
import 'package:hai_schedule/services/class_silence_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/utils/schedule_ui_tokens.dart';

class HomeNextLessonCard extends StatefulWidget {
  const HomeNextLessonCard({super.key, DateTime Function()? nowFactory})
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
    final timeConfig = provider.timeConfig;

    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final lessonDate = nowDate.add(Duration(days: dayOffset));
      final lessonWeek = provider.weekCalc.getWeekNumber(lessonDate);
      if (lessonWeek < 1 || lessonWeek > provider.weekCalc.totalWeeks) {
        continue;
      }

      final slots =
          provider
              .getDisplaySlotsForDay(lessonWeek, lessonDate.weekday)
              .where(
                (slot) =>
                    slot.isActive &&
                    slot.overrideType != ScheduleOverrideType.cancel,
              )
              .toList();
      if (slots.isEmpty) continue;

      final isToday = dayOffset == 0;

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
        final activeWeeks = slot.slot.getAllActiveWeeks();

        return _buildLessonInfo(
          slot: slot,
          lessonDate: lessonDate,
          lessonWeek: lessonWeek,
          nowDate: nowDate,
          nowMinutes: nowMinutes,
          activeWeeks:
              activeWeeks.isEmpty ? <int>[lessonWeek] : activeWeeks.toSet().toList(),
          isOngoing: isOngoing,
          timeConfig: timeConfig,
        );
      }
    }

    return null;
  }

  _NextLessonInfo _buildLessonInfo({
    required DisplayScheduleSlot slot,
    required DateTime lessonDate,
    required int lessonWeek,
    required DateTime nowDate,
    required int nowMinutes,
    required List<int> activeWeeks,
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
      lessonDate: lessonDate,
      lessonWeek: lessonWeek,
      activeWeeks: activeWeeks..sort(),
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

  String _sheetDateLabel(DateTime nowDate, DateTime lessonDate) {
    if (_isSameDate(nowDate, lessonDate)) {
      return '今天 · ${lessonDate.month}/${lessonDate.day}';
    }
    return '${_weekdayLabel(lessonDate.weekday)} · ${lessonDate.month}/${lessonDate.day}';
  }

  Future<void> _showWeeksSheet(
    BuildContext context, {
    required _NextLessonInfo info,
    required int displayWeek,
    required int totalWeeks,
    required Color baseColor,
  }) async {
    final now = widget.nowFactory();
    final nowDate = DateTime(now.year, now.month, now.day);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _HomeNextLessonWeeksSheet(
          info: info,
          displayWeek: displayWeek,
          totalWeeks: totalWeeks,
          baseColor: baseColor,
          dateLabel: _sheetDateLabel(nowDate, info.lessonDate),
        );
      },
    );
  }

  Widget _buildStatusIcon({
    required BuildContext context,
    required IconData icon,
    required Color baseColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color:
            isDark
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.46,
                )
                : Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              isDark
                  ? theme.colorScheme.outlineVariant.withValues(alpha: 0.20)
                  : Colors.white.withValues(alpha: 0.34),
          width: 0.5,
        ),
      ),
      child: Icon(icon, size: 10, color: baseColor.withValues(alpha: 0.88)),
    );
  }

  Widget _buildCardShell(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: const ValueKey('home.nextLesson.cardShell'),
      decoration: BoxDecoration(
        color:
            isDark
                ? theme.colorScheme.surface.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color:
              isDark
                  ? theme.colorScheme.outlineVariant.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.40),
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(11, 5, 11, 5),
      child: child,
    );
  }

  Widget _buildEmptyStateCard(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final accentColor = ScheduleUiTokens.terracotta;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 320;
          final indicatorHeight = isCompact ? 16.0 : 18.0;
          final badgeSize = isCompact ? 34.0 : 38.0;

          return _buildCardShell(
            context,
            child: Row(
              key: const ValueKey('home.nextLesson.empty'),
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: indicatorHeight,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '今明两天都没有课',
                        style: TextStyle(
                          fontSize: isCompact ? 12.5 : 13,
                          fontWeight: FontWeight.w800,
                          color: onSurfaceColor.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '享受你的自由时光吧。',
                        style: TextStyle(
                          fontSize: 10.2,
                          height: 1.15,
                          color: onSurfaceColor.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    size: isCompact ? 18 : 20,
                    color: accentColor.withValues(alpha: 0.90),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ScheduleProvider>();
    final info = _computeNextLesson(provider);
    if (info == null) return _buildEmptyStateCard(context);

    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.primary;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final rawWeek = provider.weekCalc.getWeekNumber(widget.nowFactory());
    final displayWeek =
        rawWeek < 1
            ? info.lessonWeek
            : rawWeek.clamp(1, provider.weekCalc.totalWeeks);

    final reminderEnabled = _reminderSnapshot?.settings.enabled == true;
    final silenceEnabled =
        _silenceSnapshot?.settings.enabled == true &&
        _silenceSnapshot?.policyAccessGranted == true;
    final sectionText = '第${info.slot.startSection}-${info.slot.endSection}节';
    final timeSectionText = [
      sectionText,
      if (info.timeText.isNotEmpty) info.timeText,
    ].join(' · ');
    final dateWeekText = [
      if (info.dateText.isNotEmpty)
        info.dateText
      else
        '今天 · ${info.lessonDate.month}/${info.lessonDate.day}',
      '第${info.lessonWeek}周',
    ].join(' · ');
    final locationText =
        info.slot.location.isNotEmpty ? info.slot.location : '地点待定';
    final teacherText = info.teacher.isNotEmpty ? info.teacher : '教师待定';
    final countdownText = info.label;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 340;
          final horizontalGap = isCompact ? 8.0 : 9.0;
          final indicatorHeight = isCompact ? 14.0 : 16.0;
          const iconSizeSmall = 11.0;
          final metaStyle = TextStyle(
            fontSize: 10.0,
            fontWeight: FontWeight.w500,
            height: 1.2,
            color: onSurfaceColor.withValues(alpha: 0.72),
          );
          final metaIconColor = baseColor.withValues(alpha: 0.76);

          Widget metaLine(
            IconData icon,
            String text, {
            Key? textKey,
            bool scrollOverflow = false,
          }) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: iconSizeSmall, color: metaIconColor),
                const SizedBox(width: 3),
                Expanded(
                  child:
                      scrollOverflow
                          ? _SlowOverflowScrollText(
                            key: textKey,
                            text: text,
                            style: metaStyle,
                          )
                          : Text(
                            key: textKey,
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaStyle,
                          ),
                ),
              ],
            );
          }

          Widget metaColumn(Widget first, Widget second) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [first, const SizedBox(height: 4), second],
            );
          }

          final progressRing = _ProgressRingButton(
            key: const ValueKey('home.nextLesson.progressRing'),
            currentWeek: displayWeek,
            totalWeeks: provider.weekCalc.totalWeeks,
            baseColor: baseColor,
            size: isCompact ? 40 : 44,
            onTap:
                () => _showWeeksSheet(
                  context,
                  info: info,
                  displayWeek: displayWeek,
                  totalWeeks: provider.weekCalc.totalWeeks,
                  baseColor: baseColor,
                ),
          );
          final hasStatus = reminderEnabled || silenceEnabled;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                info.slot.courseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isCompact ? 12.8 : 13.4,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  color: onSurfaceColor.withValues(alpha: 0.94),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: metaColumn(
                      metaLine(
                        Icons.access_time,
                        timeSectionText,
                        textKey: const ValueKey(
                          'home.nextLesson.timeSectionScroller',
                        ),
                        scrollOverflow: true,
                      ),
                      metaLine(Icons.calendar_today, dateWeekText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: metaColumn(
                      metaLine(Icons.location_on, locationText),
                      metaLine(
                        Icons.person,
                        teacherText,
                        textKey: const ValueKey(
                          'home.nextLesson.teacherScroller',
                        ),
                        scrollOverflow: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );

          final trailing = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasStatus)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (reminderEnabled)
                          _buildStatusIcon(
                            context: context,
                            icon: Icons.notifications_active_rounded,
                            baseColor: baseColor,
                          ),
                        if (reminderEnabled && silenceEnabled)
                          const SizedBox(width: 4),
                        if (silenceEnabled)
                          _buildStatusIcon(
                            context: context,
                            icon: Icons.volume_off_rounded,
                            baseColor: baseColor,
                          ),
                      ],
                    ),
                  if (hasStatus) const SizedBox(height: 2),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isCompact ? 82 : 102),
                    child: Text(
                      countdownText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: isCompact ? 12.2 : 12.8,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: baseColor.withValues(alpha: 0.96),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: isCompact ? 6 : 8),
              progressRing,
            ],
          );

          return _buildCardShell(
            context,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: indicatorHeight,
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: details),
                SizedBox(width: horizontalGap),
                trailing,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SlowOverflowScrollText extends StatefulWidget {
  const _SlowOverflowScrollText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<_SlowOverflowScrollText> createState() =>
      _SlowOverflowScrollTextState();
}

class _SlowOverflowScrollTextState extends State<_SlowOverflowScrollText> {
  final ScrollController _controller = ScrollController();
  var _scrollGeneration = 0;
  var _syncScheduled = false;

  @override
  void didUpdateWidget(covariant _SlowOverflowScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _scrollGeneration++;
      if (_controller.hasClients && _controller.offset != 0) {
        _controller.jumpTo(0);
      }
    }
  }

  @override
  void dispose() {
    _scrollGeneration++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleScrollSync();
    return ClipRect(
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: widget.style,
        ),
      ),
    );
  }

  void _scheduleScrollSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted || !_controller.hasClients) return;

      final maxScrollExtent = _controller.position.maxScrollExtent;
      if (maxScrollExtent <= 0.5) {
        _scrollGeneration++;
        if (_controller.offset != 0) _controller.jumpTo(0);
        return;
      }

      final generation = ++_scrollGeneration;
      unawaited(_scrollLoop(generation));
    });
  }

  Future<void> _scrollLoop(int generation) async {
    const edgePause = Duration(milliseconds: 900);
    const endPause = Duration(milliseconds: 1200);

    while (mounted && generation == _scrollGeneration) {
      if (!_controller.hasClients) return;
      final maxScrollExtent = _controller.position.maxScrollExtent;
      if (maxScrollExtent <= 0.5) return;

      await Future<void>.delayed(edgePause);
      if (!mounted || generation != _scrollGeneration) return;
      await _controller.animateTo(
        maxScrollExtent,
        duration: _scrollDuration(maxScrollExtent, forward: true),
        curve: Curves.linear,
      );

      await Future<void>.delayed(endPause);
      if (!mounted || generation != _scrollGeneration) return;
      await _controller.animateTo(
        0,
        duration: _scrollDuration(maxScrollExtent, forward: false),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Duration _scrollDuration(double extent, {required bool forward}) {
    final rawMs = (extent * (forward ? 90 : 60)).round();
    final minMs = forward ? 4200 : 2400;
    final maxMs = forward ? 10000 : 7000;
    return Duration(milliseconds: rawMs.clamp(minMs, maxMs).toInt());
  }
}

class _NextLessonInfo {
  const _NextLessonInfo({
    required this.slot,
    required this.teacher,
    required this.lessonDate,
    required this.lessonWeek,
    required this.activeWeeks,
    required this.label,
    required this.timeText,
    required this.startText,
    required this.endText,
    required this.dateText,
    this.isOngoing = false,
  });

  final ScheduleSlot slot;
  final String teacher;
  final DateTime lessonDate;
  final int lessonWeek;
  final List<int> activeWeeks;
  final String label;
  final String timeText;
  final String startText;
  final String endText;
  final String dateText;
  final bool isOngoing;
}

class _ProgressRingButton extends StatelessWidget {
  const _ProgressRingButton({
    super.key,
    required this.currentWeek,
    required this.totalWeeks,
    required this.baseColor,
    required this.size,
    required this.onTap,
  });

  final int currentWeek;
  final int totalWeeks;
  final Color baseColor;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final progress =
        totalWeeks <= 0
            ? 0.0
            : (currentWeek / totalWeeks).clamp(0.0, 1.0).toDouble();

    return Tooltip(
      message: '查看本学期周次分布',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _ProgressRingPainter(
                    progress: value,
                    color: baseColor,
                  ),
                  child: child,
                );
              },
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currentWeek/$totalWeeks',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: size < 56 ? 9.5 : 10.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: baseColor.withValues(alpha: 0.94),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '周次',
                      style: TextStyle(
                        fontSize: size < 56 ? 8 : 8.5,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: onSurfaceColor.withValues(alpha: 0.52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 5.5;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final basePaint =
        Paint()
          ..color = color.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;

    final progressPaint =
        Paint()
          ..color = color.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, basePaint);
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _HomeNextLessonWeeksSheet extends StatelessWidget {
  const _HomeNextLessonWeeksSheet({
    required this.info,
    required this.displayWeek,
    required this.totalWeeks,
    required this.baseColor,
    required this.dateLabel,
  });

  final _NextLessonInfo info;
  final int displayWeek;
  final int totalWeeks;
  final Color baseColor;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = ScheduleUiTokens.primaryTextFor(theme);
    final secondaryText = ScheduleUiTokens.secondaryTextFor(theme);
    final activeWeeks = info.activeWeeks.toSet();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: ClipRRect(
          borderRadius: ScheduleUiTokens.sheetRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              key: const ValueKey('home.nextLesson.weeksSheet'),
              decoration: ScheduleUiTokens.glassCardDecoration(
                theme,
                borderRadius: ScheduleUiTokens.sheetRadius,
                fillColor: ScheduleUiTokens.glassFillFor(theme, alpha: 0.88),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: secondaryText.withValues(alpha: 0.24),
                          borderRadius: ScheduleUiTokens.pillRadius,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      info.slot.courseName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '亮起的周次表示这门课在该周有课。',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _WeekSheetPill(
                          icon: Icons.calendar_today_rounded,
                          label: dateLabel,
                          tintColor: baseColor,
                        ),
                        _WeekSheetPill(
                          icon: Icons.schedule_rounded,
                          label: '第${info.slot.startSection}-${info.slot.endSection}节',
                          tintColor: baseColor,
                        ),
                        _WeekSheetPill(
                          icon: Icons.timelapse_rounded,
                          label: '第$displayWeek/$totalWeeks周',
                          tintColor: baseColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: totalWeeks,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.08,
                          ),
                      itemBuilder: (context, index) {
                        final week = index + 1;
                        final isActive = activeWeeks.contains(week);
                        final isCurrent = week == displayWeek;
                        return _WeekCell(
                          week: week,
                          isActive: isActive,
                          isCurrent: isCurrent,
                          baseColor: baseColor,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekSheetPill extends StatelessWidget {
  const _WeekSheetPill({
    required this.icon,
    required this.label,
    required this.tintColor,
  });

  final IconData icon;
  final String label;
  final Color tintColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tintColor.withValues(alpha: 0.10),
        borderRadius: ScheduleUiTokens.pillRadius,
        border: Border.all(color: tintColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tintColor.withValues(alpha: 0.90)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tintColor.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({
    required this.week,
    required this.isActive,
    required this.isCurrent,
    required this.baseColor,
  });

  final int week;
  final bool isActive;
  final bool isCurrent;
  final Color baseColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = ScheduleUiTokens.primaryTextFor(theme);
    final secondaryText = ScheduleUiTokens.secondaryTextFor(theme);
    final borderColor =
        isActive
            ? baseColor.withValues(alpha: 0.40)
            : (isCurrent
                ? baseColor.withValues(alpha: 0.22)
                : ScheduleUiTokens.glassBorderFor(theme).withValues(alpha: 0.55));
    final fillColor =
        isActive
            ? baseColor.withValues(alpha: 0.14)
            : theme.colorScheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.32 : 0.56,
            );

    return Container(
      key: ValueKey(
        'home.nextLesson.week.$week.${isActive ? 'active' : 'inactive'}',
      ),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCurrent ? 1.2 : 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$week',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1,
              color:
                  isActive
                      ? baseColor.withValues(alpha: 0.96)
                      : primaryText.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '周',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1,
              color:
                  isActive
                      ? baseColor.withValues(alpha: 0.78)
                      : secondaryText.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}
