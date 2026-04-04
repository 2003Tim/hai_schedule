import 'package:hai_schedule/models/login_fetch_coordinator_models.dart';
import 'package:hai_schedule/models/login_fetch_models.dart';

class LoginFetchCoordinatorText {
  static const emptySemesterMessage =
      '\u672a\u80fd\u68c0\u6d4b\u5230\u5b66\u671f\u4fe1\u606f\uff0c\u8bf7\u91cd\u8bd5';
  static const timeoutStatus =
      '\u8bf7\u6c42\u8d85\u65f6\uff0c\u8bf7\u70b9\u51fb\u53f3\u4e0a\u89d2\u91cd\u8bd5';
  static const fetchCompletedStatus = '\u62c9\u53d6\u5b8c\u6210';

  static const Map<String, String> _autofillStatusMessages = {
    'QR_VIEW':
        '\u68c0\u6d4b\u5230\u4e8c\u7ef4\u7801\u767b\u5f55\u9875\uff0c\u6b63\u5728\u5bfb\u627e\u8d26\u53f7\u5bc6\u7801\u767b\u5f55\u5165\u53e3...',
    'SWITCHING_TO_PASSWORD_LOGIN':
        '\u5df2\u8bc6\u522b\u4e8c\u7ef4\u7801\u767b\u5f55\uff0c\u6b63\u5728\u5207\u6362\u5230\u8d26\u53f7\u5bc6\u7801\u767b\u5f55...',
    'SWITCHED_PASSWORD_LOGIN':
        '\u5df2\u8bc6\u522b\u4e8c\u7ef4\u7801\u767b\u5f55\uff0c\u6b63\u5728\u5207\u6362\u5230\u8d26\u53f7\u5bc6\u7801\u767b\u5f55...',
    'WAITING_PASSWORD_FORM':
        '\u5df2\u70b9\u51fb\u5207\u6362\u6309\u94ae\uff0c\u6b63\u5728\u7b49\u5f85\u8d26\u53f7\u5bc6\u7801\u8868\u5355\u51fa\u73b0...',
    'WAITING_FORM':
        '\u767b\u5f55\u8868\u5355\u8fd8\u5728\u52a0\u8f7d\uff0c\u7ee7\u7eed\u5c1d\u8bd5\u8bc6\u522b...',
    'FORM_READY':
        '\u5df2\u8bc6\u522b\u5230\u8d26\u53f7\u5bc6\u7801\u8868\u5355\uff0c\u6b63\u5728\u81ea\u52a8\u586b\u5145...',
    'PARTIAL_CREDENTIALS':
        '\u5df2\u8bc6\u522b\u5230\u90e8\u5206\u767b\u5f55\u8868\u5355\uff0c\u6b63\u5728\u8865\u5168\u5e76\u7ee7\u7eed\u5c1d\u8bd5...',
    'TRUST_CHECKED':
        '\u5df2\u52fe\u9009\u8bb0\u4f4f/\u4fe1\u4efb\u9009\u9879\uff0c\u51c6\u5907\u63d0\u4ea4\u767b\u5f55...',
    'WAITING_TRUST_OPTION':
        '\u5df2\u8bc6\u522b\u5230\u201c7\u5929\u8bb0\u4f4f/\u4fe1\u4efb\u9009\u9879\u201d\uff0c\u6b63\u5728\u7b49\u5f85\u52fe\u9009\u751f\u6548...',
    'CREDENTIALS_FILLED':
        '\u5df2\u81ea\u52a8\u586b\u5145\u8d26\u53f7\u5bc6\u7801\uff0c\u51c6\u5907\u81ea\u52a8\u767b\u5f55...',
    'SUBMITTING':
        '\u767b\u5f55\u8bf7\u6c42\u5df2\u53d1\u51fa\uff0c\u6b63\u5728\u7b49\u5f85\u9875\u9762\u54cd\u5e94...',
    'SUBMITTED':
        '\u5df2\u81ea\u52a8\u63d0\u4ea4\u767b\u5f55\uff0c\u8bf7\u7a0d\u5019...',
    'VERIFICATION_REQUIRED':
        '\u68c0\u6d4b\u5230\u591a\u56e0\u5b50\u6216\u8bbe\u5907\u9a8c\u8bc1\u7801\u9a8c\u8bc1\uff0c\u9700\u8981\u4f60\u624b\u52a8\u5b8c\u6210\u540e\u518d\u7ee7\u7eed...',
  };

  static String? messageForAutofillStatus(String status) {
    return _autofillStatusMessages[status];
  }

  static LoginAutofillStateResolution resolveAutofillResult(
    LoginAutofillResult result, {
    required int attemptCount,
  }) {
    if (result.verificationRequired) {
      return const LoginAutofillStateResolution(
        statusText:
            '\u68c0\u6d4b\u5230\u591a\u56e0\u5b50\u6216\u8bbe\u5907\u9a8c\u8bc1\u7801\u6821\u9a8c\uff0c\u9700\u8981\u4f60\u624b\u52a8\u5b8c\u6210\u9a8c\u8bc1',
        stopAutofillLoop: true,
        clearPendingAutofill: true,
      );
    }

    if (result.submitted) {
      return const LoginAutofillStateResolution(
        statusText:
            '\u5df2\u81ea\u52a8\u63d0\u4ea4\u767b\u5f55\uff0c\u8bf7\u7a0d\u5019...',
        stopAutofillLoop: true,
        clearPendingAutofill: true,
      );
    }

    if (result.usernameFilled && result.passwordFilled) {
      return LoginAutofillStateResolution(
        statusText:
            attemptCount >= 3
                ? '\u5df2\u81ea\u52a8\u586b\u5145\u8d26\u53f7\u5bc6\u7801\uff0c\u6b63\u5728\u5c1d\u8bd5\u81ea\u52a8\u767b\u5f55...'
                : '\u5df2\u81ea\u52a8\u586b\u5145\u8d26\u53f7\u5bc6\u7801\uff0c\u6b63\u5728\u786e\u8ba4\u9875\u9762\u72b6\u6001...',
      );
    }

    if (result.usernameFilled || result.passwordFilled) {
      return const LoginAutofillStateResolution(
        statusText:
            '\u5df2\u8bc6\u522b\u5230\u90e8\u5206\u767b\u5f55\u8868\u5355\uff0c\u6b63\u5728\u8865\u5168\u5e76\u5c1d\u8bd5\u767b\u5f55...',
      );
    }

    return const LoginAutofillStateResolution(
      statusText:
          '\u6682\u672a\u547d\u4e2d\u8d26\u53f7\u5bc6\u7801\u8f93\u5165\u6846\uff0c\u6b63\u5728\u7ee7\u7eed\u5c1d\u8bd5...',
    );
  }

  static String initialFetchStatus(String? selectedSemesterCode) {
    return selectedSemesterCode == null
        ? '\u767b\u5f55\u6210\u529f\uff0c\u6b63\u5728\u68c0\u6d4b\u5b66\u671f\u4fe1\u606f...'
        : '\u767b\u5f55\u6210\u529f\uff0c\u51c6\u5907\u6293\u53d6 $selectedSemesterCode ...';
  }

  static String switchingSemesterStatus(String semesterCode) {
    return '\u6b63\u5728\u5207\u6362\u5230\u76ee\u6807\u5b66\u671f $semesterCode ...';
  }

  static String fetchSemesterStatus(String semesterCode) {
    return '\u5b66\u671f: $semesterCode\uff0c\u6b63\u5728\u62c9\u53d6\u8bfe\u8868...';
  }

  static String executeFailure(Object error) {
    return '\u6267\u884c\u5931\u8d25: $error';
  }

  static String requestFailure(Object error) {
    return '\u8bf7\u6c42\u5931\u8d25: $error';
  }

  static String parseFailure(Object error) {
    return '\u89e3\u6790\u5931\u8d25: $error';
  }

  static String successSnackBarText({
    required int courseCount,
    required bool cookieSnapshotCaptured,
  }) {
    return cookieSnapshotCaptured
        ? '\u6210\u529f\u62c9\u53d6 $courseCount \u95e8\u8bfe\u7a0b\uff0c\u81ea\u52a8\u540c\u6b65\u72b6\u6001\u5df2\u6062\u590d'
        : '\u6210\u529f\u62c9\u53d6 $courseCount \u95e8\u8bfe\u7a0b';
  }
}
