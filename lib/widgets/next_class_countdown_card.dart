import 'dart:async';

import 'package:flutter/material.dart';

import 'package:hai_schedule/utils/schedule_ui_tokens.dart';

class NextClassCountdownCard extends StatefulWidget {
  const NextClassCountdownCard({
    super.key,
    required this.title,
    required this.timeText,
    required this.locationText,
    required this.teacherText,
    required this.targetTime,
    this.endTime,
    required this.color,
    this.onTap,
  });

  final String title;
  final String timeText;
  final String locationText;
  final String teacherText;
  final DateTime targetTime;
  final DateTime? endTime;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<NextClassCountdownCard> createState() => _NextClassCountdownCardState();
}

class _NextClassCountdownCardState extends State<NextClassCountdownCard> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdownLabel();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 0.5,
        ),
        boxShadow: ScheduleUiTokens.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '下一节课',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.90),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                countdown,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.timeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.80),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.locationText} · ${widget.teacherText}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _countdownLabel() {
    if (widget.endTime != null && _now.isAfter(widget.endTime!)) {
      return '已结束';
    }
    if (_now.isAfter(widget.targetTime)) {
      return '进行中';
    }

    final difference = widget.targetTime.difference(_now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${difference.inMinutes}m';
  }
}
