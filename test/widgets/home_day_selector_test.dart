import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hai_schedule/services/theme_provider.dart';
import 'package:hai_schedule/widgets/home_day_selector.dart';

void main() {
  testWidgets('home day selector uses the schedule grid day header style', (
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
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: MaterialApp(
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
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home.daySelector.shell')),
      findsOneWidget,
    );
    expect(find.text('4\n月'), findsOneWidget);
    expect(find.text('一'), findsOneWidget);
    expect(find.text('周一'), findsNothing);
    expect(find.text('27'), findsOneWidget);

    final shell = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('home.daySelector.shell')),
    );
    final decoration = shell.decoration as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(15));
  });
}
