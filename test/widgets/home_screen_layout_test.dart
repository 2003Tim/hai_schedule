import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/screens/home_screen.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/theme_provider.dart';
import 'package:hai_schedule/utils/week_calculator.dart';
import 'package:hai_schedule/widgets/home_screen_sections.dart';
import 'package:hai_schedule/widgets/week_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
  });

  testWidgets('home screen renders mobile layout shell', (tester) async {
    await _pumpHome(tester, const Size(390, 844));

    expect(find.byKey(const ValueKey('home.layout.mobile')), findsOneWidget);
    expect(find.byKey(const ValueKey('home.panel.overview')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home.panel.quickActions')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home.panel.navigation')), findsOneWidget);
    expect(find.byKey(const ValueKey('home.panel.schedule')), findsOneWidget);
  });

  testWidgets('home screen renders tablet layout shell', (tester) async {
    await _pumpHome(tester, const Size(900, 1200));

    expect(find.byKey(const ValueKey('home.layout.tablet')), findsOneWidget);
    expect(find.byKey(const ValueKey('home.panel.overview')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home.panel.quickActions')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home.panel.navigation')), findsOneWidget);
    expect(find.byKey(const ValueKey('home.panel.schedule')), findsOneWidget);
  });

  testWidgets('home screen renders desktop layout shell', (tester) async {
    await _pumpHome(tester, const Size(1400, 900));

    expect(find.byKey(const ValueKey('home.layout.desktop')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home.layout.desktop.side')),
      findsOneWidget,
    );
    expect(find.text('更多设置'), findsOneWidget);
  });

  testWidgets(
    'home title tap returns to today when current semester covers today',
    (tester) async {
      final scheduleProvider = ScheduleProvider();
      await scheduleProvider.ready;
      await scheduleProvider.createSemester(
        _semesterCoveringDate(DateTime.now()),
      );
      scheduleProvider.selectWeek(1);

      final currentWeek = scheduleProvider.currentWeek;
      if (currentWeek == 1) {
        scheduleProvider.selectWeek(2);
      }

      await _pumpHome(
        tester,
        const Size(390, 844),
        scheduleProvider: scheduleProvider,
      );

      await tester.tap(find.byKey(const ValueKey('home.panel.overview')));
      await tester.pumpAndSettle();

      expect(scheduleProvider.selectedWeek, scheduleProvider.currentWeek);
    },
  );

  testWidgets(
    'home title tap shows snack when today is outside active semester',
    (tester) async {
      final scheduleProvider = ScheduleProvider();
      await scheduleProvider.ready;
      await scheduleProvider.createSemester('${DateTime.now().year + 2}1');
      scheduleProvider.selectWeek(3);

      await _pumpHome(
        tester,
        const Size(390, 844),
        scheduleProvider: scheduleProvider,
      );

      await tester.tap(find.byKey(const ValueKey('home.panel.overview')));
      await tester.pump();

      expect(find.text('今日日期不在当前学期范围内，无法跳转。'), findsOneWidget);
      expect(scheduleProvider.selectedWeek, 3);
    },
  );

  testWidgets('day view keeps the date selector below the next lesson card', (
    tester,
  ) async {
    final scheduleProvider = ScheduleProvider();
    await scheduleProvider.ready;
    final themeProvider = ThemeProvider();
    await themeProvider.ready;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ScheduleProvider>.value(
            value: scheduleProvider,
          ),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: MaterialApp(
          theme: themeProvider.themeData,
          darkTheme: themeProvider.darkThemeData,
          home: Scaffold(
            body: SizedBox.expand(
              child: HomeScheduleBody(
                provider: scheduleProvider,
                showDayView: true,
                selectedDay: 1,
                onDaySelected: (_) {},
                onLoginFetch: () {},
                onManualImport: () {},
                wrapScheduleSemantics: (child, _) => child,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.byKey(const ValueKey('home.nextLesson.cardShell'));
    final dateFinder = find.byKey(const ValueKey('home.daySelector.shell'));
    final weekFinder = find.byType(WeekSelector);
    final cardTop = tester.getTopLeft(cardFinder).dy;
    final cardBottom = tester.getBottomLeft(cardFinder).dy;
    final dateTop = tester.getTopLeft(dateFinder).dy;

    expect(cardTop, lessThan(dateTop));
    expect(
      tester.getTopLeft(dateFinder).dx,
      moreOrLessEquals(tester.getTopLeft(cardFinder).dx, epsilon: 0.1),
    );
    expect(
      tester.getTopRight(dateFinder).dx,
      moreOrLessEquals(tester.getTopRight(cardFinder).dx, epsilon: 0.1),
    );
    expect(
      dateTop - cardBottom,
      moreOrLessEquals(cardTop - tester.getBottomLeft(weekFinder).dy),
    );
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  Size logicalSize, {
  ScheduleProvider? scheduleProvider,
  ThemeProvider? themeProvider,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logicalSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final resolvedScheduleProvider = scheduleProvider ?? ScheduleProvider();
  if (scheduleProvider == null) {
    await resolvedScheduleProvider.ready;
  }

  final resolvedThemeProvider = themeProvider ?? ThemeProvider();
  if (themeProvider == null) {
    await resolvedThemeProvider.ready;
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: resolvedScheduleProvider,
        ),
        ChangeNotifierProvider<ThemeProvider>.value(
          value: resolvedThemeProvider,
        ),
      ],
      child: MaterialApp(
        theme: resolvedThemeProvider.themeData,
        darkTheme: resolvedThemeProvider.darkThemeData,
        home: const HomeScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

String _semesterCoveringDate(DateTime target) {
  final year = target.year;
  final candidates = <String>[
    '${year - 1}1',
    '${year - 1}2',
    '${year}1',
    '${year}2',
    '${year + 1}1',
  ];

  for (final code in candidates) {
    final calculator = WeekCalculator.hainanuSemester(code);
    final week = calculator.getWeekNumber(target);
    if (week >= 1 && week <= calculator.totalWeeks) {
      return code;
    }
  }

  return WeekCalculator.inferSemesterCode(target);
}
