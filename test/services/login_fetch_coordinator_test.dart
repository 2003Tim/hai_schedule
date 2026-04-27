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
        '\u9700\u8981\u5b89\u5168\u9a8c\u8bc1\uff0c\u8bf7\u5728\u624b\u673a\u4e0a\u626b\u7801\u6216\u786e\u8ba4\uff08\u82e5\u65e0\u6cd5\u626b\u7801\uff0c\u8bf7\u5c1d\u8bd5\u624b\u52a8\u64cd\u4f5c\uff09',
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
        '\u9700\u8981\u5b89\u5168\u9a8c\u8bc1\uff0c\u8bf7\u5728\u624b\u673a\u4e0a\u626b\u7801\u6216\u786e\u8ba4\uff08\u82e5\u65e0\u6cd5\u626b\u7801\uff0c\u8bf7\u5c1d\u8bd5\u624b\u52a8\u64cd\u4f5c\uff09',
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
