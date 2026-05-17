import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verification autofill statuses are idempotent while already waiting', () {
    final text = File(
      'lib/screens/login_flow_state_mixin.dart',
    ).readAsStringSync();

    expect(
      text,
      contains(
        "if (status == 'VERIFICATION_REQUIRED') {\n"
        "      if (!_awaitingSecurityVerification) {\n"
        "        _enterSecurityVerificationMode();\n"
        "      }\n"
        "      return;\n"
        "    }",
      ),
    );
    expect(
      text,
      contains(
        "if (status == 'MANUAL_LOGIN_SUBMITTED') {\n"
        "      if (!_awaitingManualWebLogin) {\n"
        "        _enterManualWebLoginMode();\n"
        "      }\n"
        "      return;\n"
        "    }",
      ),
    );
  });
}
