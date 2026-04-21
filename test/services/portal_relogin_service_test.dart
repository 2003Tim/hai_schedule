import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/invalid_credentials_exception.dart';
import 'package:hai_schedule/services/login_expired_exception.dart';
import 'package:hai_schedule/services/portal_relogin_service.dart';

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
    SecureStorageMock.clear();
  });

  group('PortalReloginService.reLogin', () {
    test(
      'throws LoginExpiredException when saved credential login fails',
      () async {
        await AuthCredentialsService.instance.save(
          username: '20230001',
          password: 'expired-password',
        );

        SavedPortalCredential? capturedCredential;
        await expectLater(
          PortalReloginService.reLogin(
            performLogin: (credential) async {
              capturedCredential = credential;
              throw const LoginExpiredException();
            },
          ),
          throwsA(
            isA<LoginExpiredException>().having(
              (error) => error.message,
              'message',
              LoginExpiredException.defaultMessage,
            ),
          ),
        );

        expect(capturedCredential?.username, '20230001');
        expect(capturedCredential?.password, 'expired-password');
      },
    );

    test(
      'throws InvalidCredentialsException when saved credential is wrong',
      () async {
        await AuthCredentialsService.instance.save(
          username: '20230001',
          password: 'wrong-password',
        );

        await expectLater(
          PortalReloginService.reLogin(
            performLogin:
                (_) async => throw const InvalidCredentialsException(),
          ),
          throwsA(
            isA<InvalidCredentialsException>().having(
              (error) => error.message,
              'message',
              InvalidCredentialsException.defaultMessage,
            ),
          ),
        );
      },
    );
  });
}
