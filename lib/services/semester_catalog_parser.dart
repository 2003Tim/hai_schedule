import 'dart:convert';

import 'package:hai_schedule/models/semester_option.dart';

class SemesterCatalogParser {
  const SemesterCatalogParser._();

  static List<SemesterOption> parseBridgePayload(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! List) {
      throw const FormatException('学期列表格式无效');
    }

    return normalize(
      decoded.whereType<Map>().map(
        (item) => SemesterOption.fromJson(Map<String, dynamic>.from(item)),
      ),
    );
  }

  static List<SemesterOption> normalize(Iterable<SemesterOption> options) {
    final merged = <String, SemesterOption>{};

    for (final option in options) {
      final code = option.normalizedCode;
      if (!RegExp(r'^\d{5}$').hasMatch(code)) {
        continue;
      }

      final existing = merged[code];
      final normalized = SemesterOption(
        code: code,
        name: option.normalizedName,
      );
      if (existing == null) {
        merged[code] = normalized;
        continue;
      }

      merged[code] =
          normalized.normalizedName.isNotEmpty ? normalized : existing;
    }

    final values =
        merged.values.toList()..sort(
          (left, right) => right.normalizedCode.compareTo(left.normalizedCode),
        );
    return values;
  }
}
