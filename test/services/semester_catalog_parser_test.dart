import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/semester_option.dart';
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
  });
}
