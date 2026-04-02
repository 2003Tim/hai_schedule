import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/utils/semester_code_formatter.dart';

void main() {
  group('semester_code_formatter', () {
    test('recognizes valid semester codes', () {
      expect(looksLikeSemesterCode('20251'), isTrue);
      expect(looksLikeSemesterCode('20252'), isTrue);
      expect(looksLikeSemesterCode('20253'), isFalse);
      expect(looksLikeSemesterCode('abc'), isFalse);
    });

    test('formats semester code into academic year label', () {
      expect(formatSemesterCode('20251'), '2025-2026 \u7b2c\u4e00\u5b66\u671f');
      expect(formatSemesterCode('20252'), '2025-2026 \u7b2c\u4e8c\u5b66\u671f');
      expect(formatSemesterCode('custom'), 'custom');
    });

    test('formats optional semester code with customizable empty label', () {
      expect(
        formatOptionalSemesterCode(null),
        '\u672a\u8bbe\u7f6e\u5b66\u671f',
      );
      expect(
        formatOptionalSemesterCode('', emptyLabel: '\u5f53\u524d\u5b66\u671f'),
        '\u5f53\u524d\u5b66\u671f',
      );
    });
  });
}
