import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/auto_sync_service.dart';

import '../test_helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const autoSyncChannel = MethodChannel('hai_schedule/auto_sync');
  const nativeCredentialsChannel = MethodChannel(
    'hai_schedule/native_credentials',
  );

  final channelCalls = <String>[];
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
    channelCalls.clear();
    failCancelBackgroundSync = false;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(autoSyncChannel, (call) async {
          channelCalls.add(call.method);
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
    'handleCredentialCleared stops after alarm cancellation failure',
    () async {
      await AuthCredentialsService.instance.save(
        username: '20250001',
        password: 'secret',
      );
      await AppStorage.instance.saveCookieSnapshot('foo=bar');
      channelCalls.clear();
      failCancelBackgroundSync = true;

      await expectLater(
        AutoSyncService.handleCredentialCleared(),
        throwsA(isA<PlatformException>()),
      );

      expect(channelCalls, <String>['cancelBackgroundSync']);
      expect(await AppStorage.instance.loadSyncInvalidationFlag(), isTrue);
      expect(SecureStorageMock.read('portal_username'), isNotNull);
      expect(SecureStorageMock.read('last_auto_sync_cookie'), isNotNull);
    },
  );
}
