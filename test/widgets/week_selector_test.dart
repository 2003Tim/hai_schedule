import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/utils/schedule_ui_tokens.dart';
import 'package:hai_schedule/widgets/week_selector.dart';

void main() {
  testWidgets('week selector renders transparent week content only', (
    tester,
  ) async {
    final theme = ThemeData(useMaterial3: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: WeekSelector(
            currentWeek: 2,
            selectedWeek: 3,
            totalWeeks: 4,
            onWeekSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('weekSelector.shellBlur')), findsNothing);
    expect(find.byKey(const ValueKey('weekSelector.shell')), findsNothing);

    final unselected = tester.widget<SizedBox>(
      find.byKey(const ValueKey('weekSelector.item.1')),
    );
    expect(unselected.width, 44);

    final selected = tester.widget<SizedBox>(
      find.byKey(const ValueKey('weekSelector.item.3')),
    );
    expect(selected.width, 44);
    expect(
      tester.widget<Text>(find.text('1')).style?.color,
      ScheduleUiTokens.adaptiveGlassTextFor(theme),
    );
  });
}
