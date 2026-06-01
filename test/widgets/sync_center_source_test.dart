import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/screens/sync_center_screen.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/schedule_provider.dart';
import 'package:hai_schedule/services/theme_provider.dart';
import 'package:hai_schedule/utils/app_platform.dart';

import '../test_helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const autoSyncChannel = MethodChannel('hai_schedule/auto_sync');
  const nativeCredentialsChannel = MethodChannel(
    'hai_schedule/native_credentials',
  );
  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const homeWidgetChannel = MethodChannel('es.antonborri.home_widget');

  setUpAll(() {
    SecureStorageMock.install();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          nativeCredentialsChannel,
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          if (call.method == 'pendingNotificationRequests') {
            return <Object?>[];
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
  });

  tearDownAll(() {
    SecureStorageMock.uninstall();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeCredentialsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
    SecureStorageMock.clear();
    AuthCredentialsService.debugForceAndroid = false;
    AppPlatform.debugOverride = const FakeAppPlatform(windows: true);
  });

  tearDown(() {
    AuthCredentialsService.debugForceAndroid = null;
    AppPlatform.debugOverride = null;
  });

  testWidgets('sync center switches active schedule source', (tester) async {
    await AuthCredentialsService.instance.save(
      username: 'grad-user',
      password: 'grad-pass',
      source: ScheduleSource.graduate,
    );
    await AuthCredentialsService.instance.save(
      username: 'under-user',
      password: 'under-pass',
      source: ScheduleSource.undergraduate,
    );
    final provider = ScheduleProvider();
    await provider.ready;
    final themeProvider = ThemeProvider();
    await themeProvider.ready;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ScheduleProvider>.value(value: provider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: const MaterialApp(home: SyncCenterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('研究生'), findsOneWidget);
    expect(find.text('本科'), findsOneWidget);
    expect(find.textContaining('gr***er'), findsOneWidget);

    await tester.tap(find.text('本科'));
    await tester.pumpAndSettle();

    expect(
      await AppStorage.instance.loadActiveScheduleSource(),
      ScheduleSource.undergraduate,
    );
    expect(find.textContaining('un***er'), findsOneWidget);
  });
}
