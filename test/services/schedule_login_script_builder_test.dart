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
        expect(script, contains('AUTOFILL_RESULT:'));
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
