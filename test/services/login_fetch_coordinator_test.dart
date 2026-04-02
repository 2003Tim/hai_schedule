import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/services/login_fetch_coordinator.dart';
import 'package:hai_schedule/services/schedule_login_fetch_service.dart';

void main() {
  group('LoginFetchCoordinator', () {
    late LoginFetchCoordinator coordinator;

    setUp(() {
      coordinator = LoginFetchCoordinator();
    });

    test('maps autofill status to user-facing text', () {
      expect(
        coordinator.messageForAutofillStatus('WAITING_FORM'),
        '\u767b\u5f55\u8868\u5355\u8fd8\u5728\u52a0\u8f7d\uff0c\u7ee7\u7eed\u5c1d\u8bd5\u8bc6\u522b...',
      );
      expect(
        coordinator.messageForAutofillStatus('VERIFICATION_REQUIRED'),
        '\u68c0\u6d4b\u5230\u591a\u56e0\u5b50\u6216\u8bbe\u5907\u9a8c\u8bc1\u7801\u9a8c\u8bc1\uff0c\u9700\u8981\u4f60\u624b\u52a8\u5b8c\u6210\u540e\u518d\u7ee7\u7eed...',
      );
      expect(coordinator.messageForAutofillStatus('UNKNOWN_STATUS'), isNull);
    });

    test('resolves autofill result state for terminal and retry states', () {
      final verificationResolution = coordinator.resolveAutofillResult(
        const LoginAutofillResult(
          usernameFilled: false,
          passwordFilled: false,
          submitted: false,
          verificationRequired: true,
        ),
        attemptCount: 1,
      );
      expect(verificationResolution.stopAutofillLoop, isTrue);
      expect(verificationResolution.clearPendingAutofill, isTrue);
      expect(
        verificationResolution.statusText,
        '\u68c0\u6d4b\u5230\u591a\u56e0\u5b50\u6216\u8bbe\u5907\u9a8c\u8bc1\u7801\u6821\u9a8c\uff0c\u9700\u8981\u4f60\u624b\u52a8\u5b8c\u6210\u9a8c\u8bc1',
      );

      final filledResolution = coordinator.resolveAutofillResult(
        const LoginAutofillResult(
          usernameFilled: true,
          passwordFilled: true,
          submitted: false,
          verificationRequired: false,
        ),
        attemptCount: 3,
      );
      expect(filledResolution.stopAutofillLoop, isFalse);
      expect(filledResolution.clearPendingAutofill, isFalse);
      expect(
        filledResolution.statusText,
        '\u5df2\u81ea\u52a8\u586b\u5145\u8d26\u53f7\u5bc6\u7801\uff0c\u6b63\u5728\u5c1d\u8bd5\u81ea\u52a8\u767b\u5f55...',
      );
    });

    test('validates and formats semester codes', () {
      expect(coordinator.looksLikeSemesterCode('20251'), isTrue);
      expect(coordinator.looksLikeSemesterCode('20253'), isFalse);
      expect(
        coordinator.formatSemesterCode('20251'),
        '2025-2026 \u7b2c\u4e00\u5b66\u671f',
      );
      expect(coordinator.formatSemesterCode('abc'), 'abc');
    });
  });
}
