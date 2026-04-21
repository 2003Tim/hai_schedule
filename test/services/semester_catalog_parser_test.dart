import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/services/catalog_parsing_exception.dart';
import 'package:hai_schedule/services/semester_catalog_parser.dart';

void main() {
  group('SemesterCatalogParser', () {
    test('normalizes and deduplicates semester options', () {
      final options = SemesterCatalogParser.parseBridgePayload(
        '[{"code":"20251","name":"2025-2026学年 第一学期"},'
        '{"code":"20252","name":"2025-2026学年 第二学期"},'
        '{"code":"20252","name":""},'
        '{"code":"bad","name":"ignored"}]',
      );

      expect(options, [
        const SemesterOption(code: '20252', name: '2025-2026学年 第二学期'),
        const SemesterOption(code: '20251', name: '2025-2026学年 第一学期'),
      ]);
    });

    test('parses semester options from portal html select tags', () {
      final options = SemesterCatalogParser.parseHtml('''
        <html>
          <body>
            <select id="semester">
              <option value="20251">2025-2026学年 第一学期</option>
              <option value="20252">2025-2026学年 第二学期</option>
            </select>
          </body>
        </html>
      ''');

      expect(options, const [
        SemesterOption(code: '20252', name: '2025-2026学年 第二学期'),
        SemesterOption(code: '20251', name: '2025-2026学年 第一学期'),
      ]);
    });

    test('falls back when option text omits the explicit semester code', () {
      final options = SemesterCatalogParser.parseHtml('''
        <html>
          <body>
            <select id="semester">
              <option value="">第二学期</option>
            </select>
          </body>
        </html>
      ''', fallbackNow: DateTime(2026, 4, 20));

      expect(options, const [SemesterOption(code: '20252', name: '第二学期')]);
    });

    test(
      'throws when portal html does not contain a valid semester catalog',
      () {
        expect(
          () => SemesterCatalogParser.parseHtml(
            '<html><body><div>当前无可解析学期</div></body></html>',
            fallbackNow: DateTime(2026, 4, 20),
          ),
          throwsA(isA<CatalogParsingException>()),
        );
      },
    );
  });
}
