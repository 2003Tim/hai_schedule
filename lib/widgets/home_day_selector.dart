import 'package:flutter/material.dart';

import 'package:hai_schedule/utils/constants.dart';
import 'package:hai_schedule/utils/schedule_ui_tokens.dart';
import 'package:hai_schedule/widgets/shared_glass_container.dart';

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
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final textColor =
              isSelected
                  ? colorScheme.primary
                  : ScheduleUiTokens.adaptiveGlassTextFor(theme);
          final metaColor =
              isSelected
                  ? colorScheme.primary.withValues(alpha: 0.78)
                  : ScheduleUiTokens.adaptiveGlassMetadataTextFor(theme);
          final weekdayLabel = '周${WeekdayNames.getShort(weekday)}';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(weekday),
              child: SharedGlassPill(
                key: ValueKey('home.daySelector.item.$weekday'),
                selected: isSelected,
                width: 46,
                height: 48,
                current: weekday == DateTime.now().weekday,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isSelected ? '${date.month}月' : weekdayLabel,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        height: 1,
                        color: metaColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (isSelected)
                      Text(
                        weekdayLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          color: metaColor,
                        ),
                      )
                    else
                      const SizedBox(height: 9.5),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
