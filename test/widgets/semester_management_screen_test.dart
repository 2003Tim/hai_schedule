import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/screens/semester_management_screen.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/widgets/home_screen_sections.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
  });

  testWidgets(
    'home overflow menu hides semester management before first sync',
    (tester) async {
      final provider = ScheduleProvider();
      await provider.ready;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeOverflowMenu(
              provider: provider,
              onSelected: (_) {},
              formatSemesterCode: (code) => code,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<HomeMenuAction>));
      await tester.pumpAndSettle();

      expect(find.text('课表同步'), findsOneWidget);
      expect(find.text('学期管理'), findsNothing);
    },
  );

  testWidgets(
    'semester management shows empty state after all semesters are deleted',
    (tester) async {
      final repository = ScheduleRepository();
      await repository.saveHasSyncedAtLeastOneSemester(true);

      final provider = ScheduleProvider();
      await provider.ready;
      await provider.reloadFromStorage();

      await tester.pumpWidget(
        _buildShell(provider, const SemesterManagementScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('semester_management.empty_state')),
        findsOneWidget,
      );
      expect(find.text('当前无学期数据'), findsOneWidget);
      expect(find.text('前往同步课表'), findsOneWidget);
    },
  );

  testWidgets(
    'new semester dialog uses catalog dropdown instead of free text input',
    (tester) async {
      final repository = ScheduleRepository();
      await repository.saveHasSyncedAtLeastOneSemester(true);
      await repository.saveKnownSemesterOptions(const <SemesterOption>[
        SemesterOption(code: '20251', name: '2025-2026学年 第一学期'),
        SemesterOption(code: '20252', name: '2025-2026学年 第二学期'),
      ]);

      final provider = ScheduleProvider();
      await provider.ready;
      await provider.reloadFromStorage();

      await tester.pumpWidget(
        _buildShell(provider, const SemesterManagementScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建学期'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('semester_management.new_semester_dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('semester_management.new_semester_dropdown')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.text('选择学期'), findsOneWidget);
    },
  );

  testWidgets('empty catalog dialog can be dismissed safely without crashing', (
    tester,
  ) async {
    final repository = ScheduleRepository();
    await repository.saveHasSyncedAtLeastOneSemester(true);

    final provider = ScheduleProvider();
    await provider.ready;
    await provider.reloadFromStorage();

    await tester.pumpWidget(
      _buildShell(provider, const SemesterManagementScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('更新学期目录'));
    await tester.pumpAndSettle();

    expect(find.text('请先同步课表以更新学期列表。'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('semester_management.new_semester_dialog')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

Widget _buildShell(ScheduleProvider provider, Widget child) {
  return ChangeNotifierProvider<ScheduleProvider>.value(
    value: provider,
    child: MaterialApp(home: child),
  );
}
