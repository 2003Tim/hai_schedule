import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/widgets/home_day_selector.dart';
import 'package:hai_schedule/widgets/shared_glass_container.dart';

void main() {
  testWidgets('home day selector renders transparent date row content', (
    tester,
  ) async {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: HomeDaySelector(
            displayDays: 2,
            selectedDay: 1,
            dateForWeekday: (weekday) => DateTime(2026, 4, 26 + weekday),
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home.daySelector.shellBlur')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('home.daySelector.shell')), findsNothing);
    expect(find.text('4月'), findsOneWidget);
    expect(find.text('27'), findsOneWidget);

    final selected = tester.widget<SharedGlassPill>(
      find.byKey(const ValueKey('home.daySelector.item.1')),
    );
    expect(selected.selected, isTrue);

    final unselected = tester.widget<SharedGlassPill>(
      find.byKey(const ValueKey('home.daySelector.item.2')),
    );
    expect(unselected.selected, isFalse);
  });
}
