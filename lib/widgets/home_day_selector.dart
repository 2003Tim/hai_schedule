import 'package:flutter/material.dart';

import 'package:hai_schedule/widgets/schedule_day_strip.dart';

class HomeDaySelector extends StatelessWidget {
  const HomeDaySelector({
    super.key,
    required this.displayDays,
    required this.selectedDay,
    required this.dateForWeekday,
    required this.onSelected,
  });

  final int displayDays;
  final int selectedDay;
  final DateTime Function(int weekday) dateForWeekday;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ScheduleDayStrip(
        surfaceKey: const ValueKey('home.daySelector.shell'),
        dayKeyPrefix: 'home.daySelector.item',
        displayDays: displayDays,
        dateForWeekday: dateForWeekday,
        highlightedWeekday: selectedDay,
        onWeekdaySelected: onSelected,
      ),
    );
  }
}
