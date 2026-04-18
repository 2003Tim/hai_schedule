import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/screens/home_screen.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/theme_provider.dart';

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
}

Future<void> _pumpHome(WidgetTester tester, Size logicalSize) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logicalSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final scheduleProvider = ScheduleProvider();
  await scheduleProvider.ready;

  final themeProvider = ThemeProvider();
  await themeProvider.ready;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: MaterialApp(
        theme: themeProvider.themeData,
        darkTheme: themeProvider.darkThemeData,
        home: const HomeScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}
