import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/theme_provider.dart';
import 'package:hai_schedule/widgets/schedule_grid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
  });

  testWidgets(
    'schedule grid keeps consecutive course cards aligned to section heights',
    (tester) async {
      final provider = ScheduleProvider();
      await provider.ready;
      await provider.setCourses([
        _buildCourse(
          id: 'course-1',
          name: '高等数学',
          startSection: 1,
          endSection: 2,
          activeWeeks: const [1],
        ),
        _buildCourse(
          id: 'course-2',
          name: '大学英语',
          startSection: 3,
          endSection: 4,
          activeWeeks: const [1],
        ),
      ], semesterCode: '20252');

      await _pumpScheduleGrid(tester, provider: provider, week: 1);

      final firstCard = find.byKey(
        const ValueKey('schedule-card-1-course-1-1-2'),
      );
      final secondCard = find.byKey(
        const ValueKey('schedule-card-1-course-2-3-4'),
      );

      expect(firstCard, findsOneWidget);
      expect(secondCard, findsOneWidget);

      final firstTop = tester.getTopLeft(firstCard).dy;
      final firstBottom = tester.getBottomLeft(firstCard).dy;
      final secondTop = tester.getTopLeft(secondCard).dy;
      expect(secondTop - firstTop, moreOrLessEquals(116, epsilon: 0.1));
      expect(secondTop - firstBottom, moreOrLessEquals(3, epsilon: 0.1));
    },
  );

  testWidgets(
    'schedule grid keeps active courses visible when non-current references overlap',
    (tester) async {
      final provider = ScheduleProvider();
      await provider.ready;
      await provider.setCourses([
        _buildCourse(
          id: 'course-ref',
          name: '线性代数',
          startSection: 1,
          endSection: 4,
          activeWeeks: const [2],
        ),
        _buildCourse(
          id: 'course-live',
          name: '大学物理',
          startSection: 3,
          endSection: 4,
          activeWeeks: const [1],
        ),
      ], semesterCode: '20252');

      await _pumpScheduleGrid(tester, provider: provider, week: 1);

      final referenceCard = find.byKey(
        const ValueKey('schedule-card-1-course-ref-1-4'),
      );
      final activeCard = find.byKey(
        const ValueKey('schedule-card-1-course-live-3-4'),
      );

      expect(referenceCard, findsOneWidget);
      expect(activeCard, findsOneWidget);

      final referenceTop = tester.getTopLeft(referenceCard).dy;
      final activeTop = tester.getTopLeft(activeCard).dy;
      expect(activeTop - referenceTop, moreOrLessEquals(116, epsilon: 0.1));
    },
  );
}

Future<void> _pumpScheduleGrid(
  WidgetTester tester, {
  required ScheduleProvider provider,
  required int week,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1280, 1800);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final themeProvider = ThemeProvider();
  await themeProvider.ready;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleProvider>.value(value: provider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: MaterialApp(
        theme: themeProvider.themeData,
        darkTheme: themeProvider.darkThemeData,
        home: Scaffold(
          body: SizedBox.expand(
            child: ScheduleGrid(provider: provider, weekOverride: week),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Course _buildCourse({
  required String id,
  required String name,
  required int startSection,
  required int endSection,
  required List<int> activeWeeks,
}) {
  return Course(
    id: id,
    code: '${id.toUpperCase()}001',
    name: name,
    className: '测试班级',
    teacher: '测试老师',
    college: '测试学院',
    credits: 2,
    totalHours: 32,
    semester: '20252',
    slots: [
      ScheduleSlot(
        courseId: id,
        courseName: name,
        weekday: 1,
        startSection: startSection,
        endSection: endSection,
        location: '教学楼 A101',
        weekRanges:
            activeWeeks
                .map((week) => WeekRange(start: week, end: week))
                .toList(),
      ),
    ],
  );
}
