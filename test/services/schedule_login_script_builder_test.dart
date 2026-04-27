import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hai_schedule/services/schedule_login_script_builder.dart';

void main() {
  group('ScheduleLoginScriptBuilder', () {
    test(
      'buildFillCredentialScript injects encoded credentials and bridge call',
      () {
        const username = 'user"01';
        const password = r'pa$$\word';

        final script = ScheduleLoginScriptBuilder.buildFillCredentialScript(
          username: username,
          password: password,
          bridgeCall: 'window.chrome.webview.postMessage',
        );

        expect(script, contains('window.chrome.webview.postMessage(message);'));
        expect(script, contains(jsonEncode(username)));
        expect(script, contains(jsonEncode(password)));
        expect(script, contains('AUTOFILL_STATUS:CREDENTIALS_FILLED'));
        expect(script, contains('AUTOFILL_STATUS:VERIFICATION_REQUIRED'));
        expect(script, contains('AUTOFILL_RESULT:'));
        expect(script, contains('LOGIN_ERROR:'));
        expect(script, contains("'#qrCode'"));
        expect(script, contains("'.qrcode-img'"));
        expect(
          script,
          contains(
            '\\u8bf7\\u4f7f\\u7528\\u6d77\\u5357\\u5927\\u5b66APP\\u626b\\u7801',
          ),
        );
        expect(script, contains('\\u4e8c\\u6b21\\u9a8c\\u8bc1'));
        expect(script, contains('\\u8eab\\u4efd\\u786e\\u8ba4'));
        expect(
          script,
          contains('\\u7528\\u6237\\u540d\\u5bc6\\u7801\\u6709\\u8bef'),
        );
        expect(script, contains('var isBlockedByError = false;'));
        expect(script, contains('if (isBlockedByError) {'));
        expect(script, contains('findLoginErrorText()'));
        expect(script, contains('attempt(true);'));
      },
    );

    test('buildFillCredentialScript supports disabled bridge and submit', () {
      final script = ScheduleLoginScriptBuilder.buildFillCredentialScript(
        username: 'demo',
        password: 'secret',
        autoSubmit: false,
      );

      expect(script, contains('if (!false) return;'));
      expect(script, isNot(contains('postMessage(message);')));
      expect(script, contains('attempt(false);'));
    });
  });
}
