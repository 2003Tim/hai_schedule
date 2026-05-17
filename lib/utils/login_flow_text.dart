class LoginFlowText {
  static String browserInitFailed(Object error) {
    return '\u6d4f\u89c8\u5668\u521d\u59cb\u5316\u5931\u8d25: $error';
  }

  static const manualLoginPrompt =
      '\u8bf7\u8f93\u5165\u8d26\u53f7\u5bc6\u7801\u767b\u5f55';
  static const tryingSavedCredentialLogin =
      '\u5df2\u68c0\u6d4b\u5230\u53ef\u7528\u8d26\u53f7\uff0c\u6b63\u5728\u5c1d\u8bd5\u81ea\u52a8\u586b\u5145\u5e76\u767b\u5f55...';
  static const autofillIncomplete =
      '\u81ea\u52a8\u767b\u5f55\u672a\u5b8c\u5168\u5b8c\u6210\uff0c\u5982\u9875\u9762\u5df2\u5207\u5230\u8d26\u5bc6\u767b\u5f55\u53ef\u624b\u52a8\u70b9\u767b\u5f55';
  static const sessionCleared =
      '\u5df2\u6e05\u9664\u65e7\u767b\u5f55\u6001\uff0c\u8bf7\u91cd\u65b0\u767b\u5f55';
  static const savedCredentialCleared =
      '\u8bf7\u8f93\u5165\u8d26\u53f7\u5bc6\u7801\u767b\u5f55';
  static const savedCredentialClearedToast =
      '\u5df2\u6e05\u9664\u4fdd\u5b58\u7684\u8d26\u53f7\u5bc6\u7801';
  static const savedCredentialUpdated =
      '\u5df2\u66f4\u65b0\u4fdd\u5b58\u7684\u8d26\u53f7\u5bc6\u7801';
  static const switchingSavedCredentialSession =
      '\u5df2\u4fdd\u5b58\u8d26\u53f7\uff0c\u6b63\u5728\u5207\u6362\u5230\u65b0\u7684\u767b\u5f55\u4f1a\u8bdd';
  static const temporaryCredentialLogin =
      '\u6b63\u5728\u4f7f\u7528\u672c\u6b21\u8f93\u5165\u7684\u8d26\u53f7\u767b\u5f55\u5e76\u540c\u6b65...';
  static const emptyDetectedSemester =
      '\u672a\u68c0\u6d4b\u5230\u5b66\u671f\u4fe1\u606f';
  static const securityVerificationRequired =
      '\u9700\u8981\u5b89\u5168\u9a8c\u8bc1\uff0c\u8bf7\u5728\u624b\u673a\u4e0a\u626b\u7801\u6216\u786e\u8ba4\uff08\u82e5\u65e0\u6cd5\u626b\u7801\uff0c\u8bf7\u5c1d\u8bd5\u624b\u52a8\u64cd\u4f5c\uff09';
  static const securityVerificationCompleted =
      '\u5b89\u5168\u9a8c\u8bc1\u5df2\u5b8c\u6210\uff0c\u6b63\u5728\u7ee7\u7eed\u540c\u6b65\u8bfe\u8868...';

  static String savedCredentialStored(String maskedUsername) {
    return '\u5df2\u4fdd\u5b58\u8d26\u53f7 $maskedUsername';
  }

  static String temporaryCredentialUsed(String maskedUsername) {
    return '\u672c\u6b21\u4f7f\u7528\u8d26\u53f7 $maskedUsername \u767b\u5f55';
  }
}
