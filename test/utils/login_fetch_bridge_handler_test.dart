import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/login_fetch_models.dart';
import 'package:hai_schedule/models/semester_option.dart';
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
        onSemesterOptions: (_) {},
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

    test('forwards login error messages', () {
      String? loginError;

      LoginFetchBridgeHandler.handle(
        message: 'LOGIN_ERROR:用户名密码有误',
        chunkState: LoginFetchChunkState(),
        onStatus: (_) {},
        onSemesterDetected: (_) {},
        onSemesterOptions: (_) {},
        onSemesterSwitched: (_) {},
        onPayloadReady: (_) {},
        onError: (_) {},
        onLoginError: (value) => loginError = value,
      );

      expect(loginError, '用户名密码有误');
    });

    test('formats semester switch error in Chinese', () {
      final errors = <String>[];
      final chunkState = LoginFetchChunkState()..arm('req-1');

      LoginFetchBridgeHandler.handle(
        message: 'SEMESTER_SWITCH_ERR:req-1:20252',
        chunkState: chunkState,
        onStatus: (_) {},
        onSemesterDetected: (_) {},
        onSemesterOptions: (_) {},
        onSemesterSwitched: (_) {},
        onPayloadReady: (_) {},
        onError: errors.add,
      );

      expect(errors, ['切换学期失败: 20252']);
    });

    test('ignores stale request messages and accepts active request only', () {
      final semesters = <String>[];
      final semesterOptions = <List<SemesterOption>>[];
      final chunkState = LoginFetchChunkState()..arm('active');

      LoginFetchBridgeHandler.handle(
        message: 'SEMESTER:stale:20251',
        chunkState: chunkState,
        onStatus: (_) {},
        onSemesterDetected: semesters.add,
        onSemesterOptions: semesterOptions.add,
        onSemesterSwitched: (_) {},
        onPayloadReady: (_) {},
        onError: (_) {},
      );
      LoginFetchBridgeHandler.handle(
        message: 'SEMESTER:active:20252',
        chunkState: chunkState,
        onStatus: (_) {},
        onSemesterDetected: semesters.add,
        onSemesterOptions: semesterOptions.add,
        onSemesterSwitched: (_) {},
        onPayloadReady: (_) {},
        onError: (_) {},
      );

      expect(semesters, ['20252']);
      expect(semesterOptions, isEmpty);
    });

    test('parses semester option payloads for the active request', () {
      final options = <List<SemesterOption>>[];
      final chunkState = LoginFetchChunkState()..arm('req-options');

      LoginFetchBridgeHandler.handle(
        message:
            'SEMESTER_OPTIONS:req-options:[{"code":"20252","name":"2025-2026学年 第二学期"}]',
        chunkState: chunkState,
        onStatus: (_) {},
        onSemesterDetected: (_) {},
        onSemesterOptions: options.add,
        onSemesterSwitched: (_) {},
        onPayloadReady: (_) {},
        onError: (_) {},
      );

      expect(options, hasLength(1));
      expect(options.single, [
        const SemesterOption(code: '20252', name: '2025-2026学年 第二学期'),
      ]);
    });

    test('rejects incomplete chunks for active request', () {
      final payloads = <String>[];
      final errors = <String>[];
      final chunkState = LoginFetchChunkState()..arm('req-2');

      LoginFetchBridgeHandler.handle(
        message: 'CHUNK_START:req-2:2:8',
        chunkState: chunkState,
        onStatus: (_) {},
        onSemesterDetected: (_) {},
        onSemesterOptions: (_) {},
        onSemesterSwitched: (_) {},
        onPayloadReady: payloads.add,
        onError: errors.add,
      );
      LoginFetchBridgeHandler.handle(
        message: 'CHUNK_DATA:req-2:0:abcd',
        chunkState: chunkState,
        onStatus: (_) {},
        onSemesterDetected: (_) {},
        onSemesterOptions: (_) {},
        onSemesterSwitched: (_) {},
        onPayloadReady: payloads.add,
        onError: errors.add,
      );
      LoginFetchBridgeHandler.handle(
        message: 'CHUNK_END:req-2',
        chunkState: chunkState,
        onStatus: (_) {},
        onSemesterDetected: (_) {},
        onSemesterOptions: (_) {},
        onSemesterSwitched: (_) {},
        onPayloadReady: payloads.add,
        onError: errors.add,
      );

      expect(payloads, isEmpty);
      expect(errors, ['课表数据分片不完整，请重试']);
    });
  });
}
