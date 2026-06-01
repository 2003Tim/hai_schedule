import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';

import '../test_helpers/secure_storage_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    AuthCredentialsService.debugForceAndroid = false;
  });

  tearDown(() {
    AuthCredentialsService.debugForceAndroid = null;
  });

  test('stores graduate and undergraduate credentials separately', () async {
    await AuthCredentialsService.instance.save(
      username: 'graduate-user',
      password: 'graduate-pass',
      source: ScheduleSource.graduate,
    );
    await AuthCredentialsService.instance.save(
      username: 'undergraduate-user',
      password: 'undergraduate-pass',
      source: ScheduleSource.undergraduate,
    );

    final graduate = await AuthCredentialsService.instance.load(
      source: ScheduleSource.graduate,
    );
    final undergraduate = await AuthCredentialsService.instance.load(
      source: ScheduleSource.undergraduate,
    );

    expect(graduate?.username, 'graduate-user');
    expect(graduate?.password, 'graduate-pass');
    expect(undergraduate?.username, 'undergraduate-user');
    expect(undergraduate?.password, 'undergraduate-pass');
    expect(SecureStorageMock.read('portal_username'), 'graduate-user');
    expect(
      SecureStorageMock.read('undergraduate.portal_username'),
      'undergraduate-user',
    );

    await AuthCredentialsService.instance.clear(
      source: ScheduleSource.undergraduate,
    );

    expect(
      await AuthCredentialsService.instance.load(
        source: ScheduleSource.undergraduate,
      ),
      isNull,
    );
    expect(
      (await AuthCredentialsService.instance.load(
        source: ScheduleSource.graduate,
      ))?.username,
      'graduate-user',
    );
  });
}
