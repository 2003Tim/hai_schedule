import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/screens/semester_management_screen.dart';
import 'package:hai_schedule/utils/week_calculator.dart';
import 'package:hai_schedule/widgets/mini_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
  });

  testWidgets('mini overlay renders active add override for today', (
    tester,
  ) async {
    final provider = ScheduleProvider();
    await provider.ready;

    final semesterCode = _semesterCoveringToday();
    await provider.createSemester(semesterCode);

    final today = provider.getDateForSlot(
      provider.currentWeek,
      provider.todayWeekday,
    );
    await provider.upsertOverride(
      ScheduleOverride(
        id: 'today-add',
        semesterCode: semesterCode,
        dateKey: _dateKey(today),
        weekday: provider.todayWeekday,
        startSection: 1,
        endSection: 2,
        type: ScheduleOverrideType.add,
        courseName: '临时加课',
        teacher: '王老师',
        location: '报告厅',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 480,
              child: MiniScheduleOverlay(
                provider: provider,
                onClose: () {},
                onOpenMain: () {},
                opacity: 0.95,
                alwaysOnTop: true,
                onOpacityChanged: (_) {},
                onAlwaysOnTopChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('临时加课'), findsOneWidget);
    expect(find.text('今天没有课，好好休息'), findsNothing);
  });

  testWidgets('semester management uses content width inside desktop shell', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1100, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = ScheduleProvider();
    await provider.ready;
    await provider.createSemester('20252');
    await provider.createSemester('20251');

    await tester.pumpWidget(
      ChangeNotifierProvider<ScheduleProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Row(
            children: const [
              SizedBox(width: 252),
              SizedBox(width: 848, child: SemesterManagementScreen()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final wideSizedBoxes = find.byWidgetPredicate(
      (widget) => widget is SizedBox && widget.width == 560,
    );
    expect(wideSizedBoxes, findsNothing);
  });
}

String _semesterCoveringToday() {
  final now = DateTime.now();
  final year = now.year;
  final candidates = <String>[
    '${year - 1}1',
    '${year - 1}2',
    '${year}1',
    '${year}2',
    '${year + 1}1',
  ];

  for (final code in candidates) {
    final calculator = WeekCalculator.hainanuSemester(code);
    final week = calculator.getWeekNumber(now);
    if (week >= 1 && week <= calculator.totalWeeks) {
      return code;
    }
  }

  return WeekCalculator.inferSemesterCode(now);
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
