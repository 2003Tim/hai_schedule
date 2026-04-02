import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/utils/login_fetch_coordinator_text.dart';

void main() {
  group('LoginFetchCoordinatorText', () {
    test('builds request lifecycle messages', () {
      expect(
        LoginFetchCoordinatorText.initialFetchStatus(null),
        '\u767b\u5f55\u6210\u529f\uff0c\u6b63\u5728\u68c0\u6d4b\u5b66\u671f\u4fe1\u606f...',
      );
      expect(
        LoginFetchCoordinatorText.initialFetchStatus('20252'),
        '\u767b\u5f55\u6210\u529f\uff0c\u51c6\u5907\u6293\u53d6 20252 ...',
      );
      expect(
        LoginFetchCoordinatorText.switchingSemesterStatus('20252'),
        '\u6b63\u5728\u5207\u6362\u5230\u76ee\u6807\u5b66\u671f 20252 ...',
      );
      expect(
        LoginFetchCoordinatorText.fetchSemesterStatus('20252'),
        '\u5b66\u671f: 20252\uff0c\u6b63\u5728\u62c9\u53d6\u8bfe\u8868...',
      );
    });

    test('builds success snackbar text from cookie capture state', () {
      expect(
        LoginFetchCoordinatorText.successSnackBarText(
          courseCount: 12,
          cookieSnapshotCaptured: true,
        ),
        '\u6210\u529f\u62c9\u53d6 12 \u95e8\u8bfe\u7a0b\uff0c\u81ea\u52a8\u540c\u6b65\u72b6\u6001\u5df2\u6062\u590d',
      );
      expect(
        LoginFetchCoordinatorText.successSnackBarText(
          courseCount: 8,
          cookieSnapshotCaptured: false,
        ),
        '\u6210\u529f\u62c9\u53d6 8 \u95e8\u8bfe\u7a0b',
      );
    });
  });
}
