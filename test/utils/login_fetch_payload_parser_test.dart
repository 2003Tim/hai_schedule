import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/login_fetch_models.dart';
import 'package:hai_schedule/utils/login_fetch_payload_parser.dart';

void main() {
  group('LoginFetchPayloadParser', () {
    test('throws on non-zero api code', () {
      expect(
        () => LoginFetchPayloadParser.parseCourses('{"code":"1"}'),
        throwsA(
          isA<LoginFetchException>().having(
            (e) => e.message,
            'message',
            contains('\u63a5\u53e3\u5f02\u5e38'),
          ),
        ),
      );
    });

    test('throws when payload has no parsable courses', () {
      expect(
        () => LoginFetchPayloadParser.parseCourses('{"code":"0","datas":{}}'),
        throwsA(
          isA<LoginFetchException>().having(
            (e) => e.message,
            'message',
            contains('\u672a\u89e3\u6790\u5230\u8bfe\u7a0b\u6570\u636e'),
          ),
        ),
      );
    });
  });
}
