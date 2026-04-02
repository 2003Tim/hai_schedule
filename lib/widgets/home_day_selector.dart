import 'package:flutter/material.dart';

import '../utils/constants.dart';

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
    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: displayDays,
        itemBuilder: (context, index) {
          final weekday = index + 1;
          final date = dateForWeekday(weekday);
          final isSelected = weekday == selectedDay;
          final colorScheme = Theme.of(context).colorScheme;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '周${WeekdayNames.getShort(weekday)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
              onSelected: (_) => onSelected(weekday),
            ),
          );
        },
      ),
    );
  }
}
