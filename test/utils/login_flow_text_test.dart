import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/utils/login_flow_text.dart';

void main() {
  group('LoginFlowText', () {
    test('provides stable login page messages', () {
      expect(
        LoginFlowText.manualLoginPrompt,
        '\u8bf7\u8f93\u5165\u8d26\u53f7\u5bc6\u7801\u767b\u5f55',
      );
      expect(
        LoginFlowText.tryingSavedCredentialLogin,
        '\u68c0\u6d4b\u5230\u5df2\u4fdd\u5b58\u8d26\u53f7\uff0c\u6b63\u5728\u5c1d\u8bd5\u81ea\u52a8\u586b\u5145\u5e76\u767b\u5f55...',
      );
      expect(
        LoginFlowText.autofillIncomplete,
        '\u81ea\u52a8\u767b\u5f55\u672a\u5b8c\u5168\u5b8c\u6210\uff0c\u5982\u9875\u9762\u5df2\u5207\u5230\u8d26\u5bc6\u767b\u5f55\u53ef\u624b\u52a8\u70b9\u767b\u5f55',
      );
    });

    test('formats saved credential snackbar text', () {
      expect(
        LoginFlowText.savedCredentialStored('2025****01'),
        '\u5df2\u4fdd\u5b58\u8d26\u53f7 2025****01',
      );
      expect(
        LoginFlowText.browserInitFailed('x'),
        '\u6d4f\u89c8\u5668\u521d\u59cb\u5316\u5931\u8d25: x',
      );
    });
  });
}
