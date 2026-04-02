import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/login_fetch_models.dart';
import 'package:hai_schedule/utils/login_fetch_bridge_handler.dart';

void main() {
  group('LoginFetchBridgeHandler', () {
    test('parses autofill result flags', () {
      final results = <LoginAutofillResult>[];

      LoginFetchBridgeHandler.handle(
        message: 'AUTOFILL_RESULT:1:0:1:0',
        chunkState: LoginFetchChunkState(),
        onStatus: (_) {},
        onSemesterDetected: (_) {},
        onSemesterSwitched: (_) {},
        onPayloadReady: (_) {},
        onError: (_) {},
        onAutofillResult: results.add,
      );

      expect(results, hasLength(1));
      expect(results.single.usernameFilled, isTrue);
      expect(results.single.passwordFilled, isFalse);
      expect(results.single.submitted, isTrue);
      expect(results.single.verificationRequired, isFalse);
    });

    test('formats semester switch error in Chinese', () {
      final errors = <String>[];

      LoginFetchBridgeHandler.handle(
        message: 'SEMESTER_SWITCH_ERR:20252',
        chunkState: LoginFetchChunkState(),
        onStatus: (_) {},
        onSemesterDetected: (_) {},
        onSemesterSwitched: (_) {},
        onPayloadReady: (_) {},
        onError: errors.add,
      );

      expect(errors, ['\u5207\u6362\u5b66\u671f\u5931\u8d25: 20252']);
    });
  });
}
