import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/auto_sync_service.dart';
import 'package:hai_schedule/utils/app_platform.dart';

import '../test_helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const autoSyncChannel = MethodChannel('hai_schedule/auto_sync');
  const nativeCredentialsChannel = MethodChannel(
    'hai_schedule/native_credentials',
  );

  final channelCalls = <String>[];
  final autoSyncCalls = <MethodCall>[];
  late bool failCancelBackgroundSync;

  setUpAll(() {
    SecureStorageMock.install();
  });

  tearDownAll(() {
    SecureStorageMock.uninstall();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
    SecureStorageMock.clear();
    AutoSyncService.debugForceAndroid = true;
    AuthCredentialsService.debugForceAndroid = true;
    AppStorage.debugForceAndroid = true;
    AppPlatform.debugOverride = const FakeAppPlatform(android: true);
    channelCalls.clear();
    autoSyncCalls.clear();
    failCancelBackgroundSync = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, (call) async {
          channelCalls.add(call.method);
          autoSyncCalls.add(call);
          if (call.method == 'cancelBackgroundSync' &&
              failCancelBackgroundSync) {
            throw PlatformException(
              code: 'cancel_failed',
              message: 'cancel failed',
            );
          }
          return true;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeCredentialsChannel, (call) async {
          channelCalls.add(call.method);
          return switch (call.method) {
            'saveCredential' => true,
            'clearCredential' => true,
            'saveCookieSnapshot' => true,
            'clearCookieSnapshot' => true,
            'loadCookieSnapshot' => null,
            'loadCredential' => null,
            _ => null,
          };
        });
  });

  tearDown(() {
    AutoSyncService.debugForceAndroid = null;
    AuthCredentialsService.debugForceAndroid = null;
    AppStorage.debugForceAndroid = null;
    AppPlatform.debugOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeCredentialsChannel, null);
  });

  test(
    'handleCredentialCleared invalidates then clears native state in order',
    () async {
      await AuthCredentialsService.instance.save(
        username: '20250001',
        password: 'secret',
      );
      await AppStorage.instance.saveCookieSnapshot('foo=bar');
      channelCalls.clear();

      await AutoSyncService.handleCredentialCleared();

      expect(channelCalls, <String>[
        'cancelBackgroundSync',
        'clearCredential',
        'clearCookieSnapshot',
        'clearCookies',
      ]);
      expect(await AppStorage.instance.loadSyncInvalidationFlag(), isTrue);
      expect(SecureStorageMock.read('portal_username'), isNull);
      expect(SecureStorageMock.read('portal_password'), isNull);
      expect(SecureStorageMock.read('last_auto_sync_cookie'), isNull);
    },
  );

  test(
    'handleCredentialCleared continues clearing after alarm cancellation failure',
    () async {
      await AuthCredentialsService.instance.save(
        username: '20250001',
        password: 'secret',
      );
      await AppStorage.instance.saveCookieSnapshot('foo=bar');
      channelCalls.clear();
      failCancelBackgroundSync = true;

      await AutoSyncService.handleCredentialCleared();

      expect(channelCalls, <String>[
        'cancelBackgroundSync',
        'clearCredential',
        'clearCookieSnapshot',
        'clearCookies',
      ]);
      expect(await AppStorage.instance.loadSyncInvalidationFlag(), isTrue);
      expect(SecureStorageMock.read('portal_username'), isNull);
      expect(SecureStorageMock.read('portal_password'), isNull);
      expect(SecureStorageMock.read('last_auto_sync_cookie'), isNull);
    },
  );

  test(
    'ensureBackgroundSchedule cancels native alarm for undergraduate',
    () async {
      await AppStorage.instance.saveActiveScheduleSource(
        ScheduleSource.undergraduate,
      );
      await AppStorage.instance.saveAutoSyncSettings('daily');
      autoSyncCalls.clear();

      await AutoSyncService.ensureBackgroundSchedule(
        credentialReadyOverride: true,
      );

      final cancelCalls =
          autoSyncCalls
              .where((call) => call.method == 'cancelBackgroundSync')
              .toList();
      expect(cancelCalls, hasLength(1));
      expect(
        cancelCalls.single.arguments,
        containsPair('source', ScheduleSource.undergraduate.value),
      );
      expect(
        await AppStorage.instance.loadActiveScheduleSource(),
        ScheduleSource.undergraduate,
      );
      expect(
        (await AppStorage.instance.loadAutoSyncRecord()).nextSyncTime,
        isNull,
      );
    },
  );
}
