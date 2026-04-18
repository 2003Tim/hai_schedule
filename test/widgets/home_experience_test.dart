import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/theme_provider.dart';
import 'package:hai_schedule/utils/week_calculator.dart';
import 'package:hai_schedule/widgets/daily_schedule_view.dart';
import 'package:hai_schedule/widgets/home_next_lesson_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
  });

  testWidgets(
    'home next lesson card falls forward to tomorrow when today has no remaining classes',
    (tester) async {
      final provider = ScheduleProvider();
      await provider.ready;
      final themeProvider = ThemeProvider();
      await themeProvider.ready;

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await provider.createSemester(_semesterCoveringDate(tomorrow));
      await provider.upsertOverride(
        ScheduleOverride(
          id: 'next-tomorrow',
          semesterCode: provider.currentSemesterCode!,
          dateKey: _dateKey(tomorrow),
          weekday: tomorrow.weekday,
          startSection: 1,
          endSection: 2,
          type: ScheduleOverrideType.add,
          courseName: '明天课程',
          teacher: '李老师',
          location: '教学楼A',
        ),
      );

      final now = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        21,
      );

      await tester.pumpWidget(
        _TestShell(
          scheduleProvider: provider,
          themeProvider: themeProvider,
          child: HomeNextLessonCard(nowFactory: () => now),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('明天课程'), findsOneWidget);
      expect(find.text('明天'), findsOneWidget);
      expect(
        find.textContaining('${tomorrow.month}/${tomorrow.day}'),
        findsOneWidget,
      );
    },
  );

  testWidgets('home next lesson card keeps a warm empty state for free days', (
    tester,
  ) async {
    final provider = ScheduleProvider();
    await provider.ready;
    final themeProvider = ThemeProvider();
    await themeProvider.ready;

    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      10,
    );

    await tester.pumpWidget(
      _TestShell(
        scheduleProvider: provider,
        themeProvider: themeProvider,
        child: HomeNextLessonCard(nowFactory: () => now),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home.nextLesson.empty')), findsOneWidget);
    expect(find.text('今明两天都没有课'), findsOneWidget);
    expect(find.text('享受你的自由时光吧。'), findsOneWidget);
  });

  testWidgets('home next lesson card opens active week overview from progress ring', (
    tester,
  ) async {
    final provider = ScheduleProvider();
    await provider.ready;
    final themeProvider = ThemeProvider();
    await themeProvider.ready;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final semesterCode = _semesterCoveringDate(tomorrow);
    final lessonWeek = WeekCalculator.hainanuSemester(
      semesterCode,
    ).getWeekNumber(tomorrow);
    await provider.setCourses(<Course>[
      Course(
        id: 'course-sheet',
        code: 'CS101',
        name: '进度总览课',
        className: '1班',
        teacher: '陈老师',
        college: '信息学院',
        credits: 2,
        totalHours: 32,
        semester: semesterCode,
        slots: <ScheduleSlot>[
          ScheduleSlot(
            courseId: 'course-sheet',
            courseName: '进度总览课',
            teacher: '陈老师',
            weekday: tomorrow.weekday,
            startSection: 1,
            endSection: 2,
            location: '教学楼C',
            weekRanges: <WeekRange>[
              WeekRange(start: lessonWeek, end: lessonWeek),
            ],
          ),
        ],
      ),
    ], semesterCode: semesterCode);

    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      21,
    );

    await tester.pumpWidget(
      _TestShell(
        scheduleProvider: provider,
        themeProvider: themeProvider,
        child: HomeNextLessonCard(nowFactory: () => now),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home.nextLesson.progressRing')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('home.nextLesson.progressRing')));
    await tester.pumpAndSettle();

    final inactiveWeek = lessonWeek == 1 ? 2 : 1;
    expect(
      find.byKey(const ValueKey('home.nextLesson.weeksSheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('home.nextLesson.week.$lessonWeek.active')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('home.nextLesson.week.$inactiveWeek.inactive')),
      findsOneWidget,
    );
  });

  testWidgets('daily schedule view copy reflects the selected day', (
    tester,
  ) async {
    final provider = ScheduleProvider();
    await provider.ready;
    final themeProvider = ThemeProvider();
    await themeProvider.ready;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await provider.createSemester(_semesterCoveringDate(tomorrow));
    await provider.upsertOverride(
      ScheduleOverride(
        id: 'daily-tomorrow',
        semesterCode: provider.currentSemesterCode!,
        dateKey: _dateKey(tomorrow),
        weekday: tomorrow.weekday,
        startSection: 3,
        endSection: 4,
        type: ScheduleOverrideType.add,
        courseName: '周末实验',
        teacher: '王老师',
        location: '实验楼B',
      ),
    );

    await tester.pumpWidget(
      _TestShell(
        scheduleProvider: provider,
        themeProvider: themeProvider,
        child: DailyScheduleView(
          provider: provider,
          week: provider.weekCalc.getWeekNumber(tomorrow),
          weekday: tomorrow.weekday,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        '周${_weekdayLabel(tomorrow.weekday)} · ${tomorrow.month}/${tomorrow.day}',
      ),
      findsOneWidget,
    );
    expect(find.text('明天有 1 节课，提前做好准备'), findsOneWidget);
    expect(find.textContaining('今天有'), findsNothing);
  });
}

class _TestShell extends StatelessWidget {
  const _TestShell({
    required this.scheduleProvider,
    required this.themeProvider,
    required this.child,
  });

  final ScheduleProvider scheduleProvider;
  final ThemeProvider themeProvider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: MaterialApp(
        theme: themeProvider.themeData,
        darkTheme: themeProvider.darkThemeData,
        home: Scaffold(body: child),
      ),
    );
  }
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

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _weekdayLabel(int weekday) {
  const labels = <String>['一', '二', '三', '四', '五', '六', '日'];
  return labels[(weekday - 1).clamp(0, 6)];
}
