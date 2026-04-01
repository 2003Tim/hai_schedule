import 'dart:async';
import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/schedule_provider.dart';
import '../utils/constants.dart';

class MiniScheduleOverlay extends StatefulWidget {
  final ScheduleProvider provider;
  final VoidCallback onClose;
  final VoidCallback onOpenMain;
  final double opacity;
  final bool alwaysOnTop;
  final ValueChanged<double> onOpacityChanged;
  final ValueChanged<bool> onAlwaysOnTopChanged;

  const MiniScheduleOverlay({
    super.key,
    required this.provider,
    required this.onClose,
    required this.onOpenMain,
    required this.opacity,
    required this.alwaysOnTop,
    required this.onOpacityChanged,
    required this.onAlwaysOnTopChanged,
  });

  @override
  State<MiniScheduleOverlay> createState() => _MiniScheduleOverlayState();
}

class _MiniScheduleOverlayState extends State<MiniScheduleOverlay> {
  Timer? _timer;
  int _nowMinutes = 0;
  int _dayOffset = 0;
  bool _showSettings = false;

  ScheduleProvider get p => widget.provider;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() => _nowMinutes = now.hour * 60 + now.minute);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  (DateTime date, int weekday, int week) _getTargetDay() {
    final now = DateTime.now();
    final target = now.add(Duration(days: _dayOffset));
    return (target, target.weekday, p.weekCalc.getWeekNumber(target));
  }

  List<_SlotInfo> _getSlots(int week, int weekday) {
    final tc = p.timeConfig;
    final slots = <_SlotInfo>[];
    for (final course in p.courses) {
      for (final slot in course.slots) {
        if (slot.weekday == weekday && slot.isActiveInWeek(week)) {
          slots.add(_SlotInfo(
            slot: slot,
            teacher: course.teacher,
            times: tc.getSlotTime(slot.startSection, slot.endSection),
          ));
        }
      }
    }
    slots.sort((a, b) => a.slot.startSection.compareTo(b.slot.startSection));
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final (date, weekday, week) = _getTargetDay();
    final slots = _getSlots(week, weekday);
    final isToday = _dayOffset == 0;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              _buildHeader(context, date, weekday, week, isToday),
              Expanded(
                child: slots.isEmpty
                    ? _buildEmpty(context, isToday)
                    : _buildTimeline(context, slots, isToday),
              ),
              _buildFooter(context, slots, isToday),
              // 设置面板（可折叠）
              if (_showSettings) _buildSettings(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DateTime date, int weekday,
      int week, bool isToday) {
    final cs = Theme.of(context).colorScheme;

    final dateLabel = isToday
        ? '今天'
        : _dayOffset == 1
            ? '明天'
            : _dayOffset == -1
                ? '昨天'
                : '${date.month}/${date.day}';

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 4, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          _tapIcon(Icons.chevron_left_rounded, 20, cs.onSurface.withValues(alpha: 0.4),
              () => setState(() => _dayOffset--)),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _dayOffset = 0),
              child: Column(
                children: [
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '星期${WeekdayNames.getShort(weekday)}  第$week周',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _tapIcon(Icons.chevron_right_rounded, 20, cs.onSurface.withValues(alpha: 0.4),
              () => setState(() => _dayOffset++)),
          const SizedBox(width: 2),
          _tapIcon(Icons.open_in_new_rounded, 15, cs.onSurface.withValues(alpha: 0.35),
              widget.onOpenMain),
          _tapIcon(Icons.close_rounded, 15, cs.onSurface.withValues(alpha: 0.35),
              widget.onClose),
        ],
      ),
    );
  }

  Widget _tapIcon(IconData icon, double size, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isToday) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isToday ? Icons.wb_sunny_rounded : Icons.event_available_rounded,
            size: 36,
            color: cs.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 10),
          Text(
            isToday ? '今天没有课，好好休息' : '这天没有课',
            style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, List<_SlotInfo> slots, bool isToday) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      itemCount: slots.length,
      itemBuilder: (context, index) =>
          _buildItem(context, slots[index], isToday, index == slots.length - 1),
    );
  }

  Widget _buildItem(
      BuildContext context, _SlotInfo info, bool isToday, bool isLast) {
    final cs = Theme.of(context).colorScheme;
    final slot = info.slot;
    final startTime = info.times?.$1 ?? '';
    final endTime = info.times?.$2 ?? '';
    final tc = p.timeConfig;

    final startMin = tc.getClassTime(slot.startSection)?.startMinutes ?? 0;
    final endMin = tc.getClassTime(slot.endSection)?.endMinutes ?? 0;

    _Status status;
    if (!isToday) {
      status = _Status.neutral;
    } else if (_nowMinutes < startMin) {
      status = _Status.upcoming;
    } else if (_nowMinutes <= endMin) {
      status = _Status.ongoing;
    } else {
      status = _Status.finished;
    }

    final color = CourseColors.getColor(slot.courseName);
    final isOngoing = status == _Status.ongoing;
    final isFinished = status == _Status.finished;
    final dimText = cs.onSurface.withValues(alpha: isFinished ? 0.25 : 0.5);
    final mainText = isFinished ? cs.onSurface.withValues(alpha: 0.3) : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Text(startTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOngoing ? color : dimText,
                    )),
                Text(endTime,
                    style: TextStyle(
                      fontSize: 9,
                      color: cs.onSurface.withValues(alpha: isFinished ? 0.15 : 0.3),
                    )),
                if (!isLast)
                  Container(
                    width: 1,
                    height: 14,
                    margin: const EdgeInsets.only(top: 4),
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOngoing
                    ? color.withValues(alpha: 0.1)
                    : cs.surfaceContainerHighest.withValues(alpha: isFinished ? 0.3 : 0.6),
                borderRadius: BorderRadius.circular(10),
                border: isOngoing
                    ? Border.all(color: color.withValues(alpha: 0.35))
                    : Border.all(color: cs.outlineVariant.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isFinished ? cs.onSurface.withValues(alpha: 0.15) : color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          slot.courseName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: mainText,
                            decoration: isFinished ? TextDecoration.lineThrough : null,
                            decorationColor: cs.onSurface.withValues(alpha: 0.2),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOngoing) _badge('进行中', color, color.withValues(alpha: 0.12)),
                      if (status == _Status.upcoming && _isNext(info))
                        _countdownBadge(startMin, cs),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: dimText),
                        const SizedBox(width: 3),
                        Text(_shortLoc(slot.location),
                            style: TextStyle(fontSize: 11, color: dimText)),
                        if (info.teacher.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.person_outline_rounded, size: 12, color: dimText),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(_shortTeacher(info.teacher),
                                style: TextStyle(fontSize: 11, color: dimText),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 15, top: 3),
                    child: Text(
                      '第${slot.startSection}-${slot.endSection}节',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: isFinished ? 0.15 : 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Widget _countdownBadge(int startMin, ColorScheme cs) {
    final diff = startMin - _nowMinutes;
    if (diff <= 0) return const SizedBox.shrink();
    final text = diff < 60 ? '$diff分钟后' : '${diff ~/ 60}h${diff % 60}m后';
    return _badge(text, cs.primary, cs.primary.withValues(alpha: 0.1));
  }

  /// 底部：课程统计 + 设置按钮
  Widget _buildFooter(BuildContext context, List<_SlotInfo> slots, bool isToday) {
    final cs = Theme.of(context).colorScheme;
    final tc = p.timeConfig;
    int done = 0;
    if (isToday) {
      for (final s in slots) {
        final endMin = tc.getClassTime(s.slot.endSection)?.endMinutes ?? 0;
        if (_nowMinutes > endMin) done++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          if (slots.isNotEmpty) ...[
            Text('共 ${slots.length} 节',
                style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.35))),
            if (isToday && done > 0) ...[
              const SizedBox(width: 6),
              Text('已完成 $done/${slots.length}',
                  style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.25))),
            ],
          ],
          if (_dayOffset != 0)
            GestureDetector(
              onTap: () => setState(() => _dayOffset = 0),
              child: Text('回到今天',
                  style: TextStyle(
                      fontSize: 10, color: cs.primary, fontWeight: FontWeight.w500)),
            ),
          const Spacer(),
          // 设置齿轮按钮
          GestureDetector(
            onTap: () => setState(() => _showSettings = !_showSettings),
            child: Icon(
              _showSettings ? Icons.expand_more_rounded : Icons.settings_rounded,
              size: 15,
              color: cs.onSurface.withValues(alpha: _showSettings ? 0.5 : 0.3),
            ),
          ),
        ],
      ),
    );
  }

  /// 设置面板
  Widget _buildSettings(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // 透明度滑块
          Row(
            children: [
              Icon(Icons.opacity_rounded, size: 14, color: cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text('透明度',
                  style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: cs.primary,
                    inactiveTrackColor: cs.onSurface.withValues(alpha: 0.1),
                    thumbColor: cs.primary,
                  ),
                  child: Slider(
                    value: widget.opacity,
                    min: 0.3,
                    max: 1.0,
                    onChanged: widget.onOpacityChanged,
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${(widget.opacity * 100).round()}%',
                  style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.4)),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          // 置顶开关
          GestureDetector(
            onTap: () => widget.onAlwaysOnTopChanged(!widget.alwaysOnTop),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    widget.alwaysOnTop ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 14,
                    color: widget.alwaysOnTop
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                  Text('窗口置顶',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                  const Spacer(),
                  // 简易开关指示
                  Container(
                    width: 32,
                    height: 18,
                    decoration: BoxDecoration(
                      color: widget.alwaysOnTop
                          ? cs.primary.withValues(alpha: 0.2)
                          : cs.onSurface.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: widget.alwaysOnTop
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: widget.alwaysOnTop ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isNext(_SlotInfo info) {
    if (_dayOffset != 0) return false;
    final m = p.timeConfig.getClassTime(info.slot.startSection)?.startMinutes ?? 0;
    return m > _nowMinutes;
  }

  String _shortLoc(String l) => l.replaceAll(RegExp(r'\(.*?\)'), '').trim();

  String _shortTeacher(String t) {
    if (t.contains(',')) return t.split(',').first;
    if (t.contains('，')) return t.split('，').first;
    return t;
  }
}

class _SlotInfo {
  final ScheduleSlot slot;
  final String teacher;
  final (String, String)? times;
  _SlotInfo({required this.slot, required this.teacher, required this.times});
}

enum _Status { upcoming, ongoing, finished, neutral }
