import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';

import '../test_helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const homeWidgetChannel = MethodChannel('es.antonborri.home_widget');
  const autoSyncChannel = MethodChannel('hai_schedule/auto_sync');
  const nativeCredentialsChannel = MethodChannel(
    'hai_schedule/native_credentials',
  );

  setUpAll(() {
    SecureStorageMock.install();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          if (call.method == 'pendingNotificationRequests') {
            return <Object?>[];
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, (call) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeCredentialsChannel, (call) async => null);
  });

  tearDownAll(() {
    SecureStorageMock.uninstall();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeCredentialsChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppStorage.instance.resetForTesting();
    SecureStorageMock.clear();
  });

  group('ScheduleProvider.importFromJson error handling', () {
    late ScheduleProvider provider;

    setUp(() {
      provider = ScheduleProvider();
    });

    test('throws FormatException for invalid JSON string', () async {
      await expectLater(
        provider.importFromJson('not valid json'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('JSON 格式无效'),
          ),
        ),
      );
    });

    test('throws FormatException for JSON array at root', () async {
      await expectLater(
        provider.importFromJson('[]'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('顶层结构必须是对象'),
          ),
        ),
      );
    });

    test('throws FormatException for JSON null at root', () async {
      await expectLater(
        provider.importFromJson('null'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('顶层结构必须是对象'),
          ),
        ),
      );
    });

    test('throws FormatException for JSON number at root', () async {
      await expectLater(
        provider.importFromJson('42'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when no courses parsed from valid JSON', () async {
      await expectLater(
        provider.importFromJson('{}'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('未解析到课程数据'),
          ),
        ),
      );
    });
  });
}
