import 'dart:convert';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/utils/week_calculator.dart';

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

  static List<SemesterOption> parseHtml(String html, {DateTime? fallbackNow}) {
    final options = <SemesterOption>[];

    try {
      final selectMatches = RegExp(
        r'<select\b[\s\S]*?</select>',
        caseSensitive: false,
      ).allMatches(html);
      for (final selectMatch in selectMatches) {
        final selectHtml = selectMatch.group(0);
        if (selectHtml == null || selectHtml.isEmpty) {
          continue;
        }
        options.addAll(_parseOptionTags(selectHtml));
      }
    } catch (_) {
      // Fall through to the semester-code fallback below.
    }

    final normalized = normalize(options);
    if (normalized.isNotEmpty) {
      return normalized;
    }

    final fallbackCode =
        _inferSemesterCodeFromHtml(html) ??
        WeekCalculator.inferSemesterCode(fallbackNow ?? DateTime.now());
    return <SemesterOption>[
      SemesterOption(
        code: fallbackCode,
        name: _formatFallbackSemesterName(fallbackCode),
      ),
    ];
  }

  static List<SemesterOption> _parseOptionTags(String selectHtml) {
    final items = <SemesterOption>[];
    final optionRegex = RegExp(
      r'<option\b([^>]*)>([\s\S]*?)</option>',
      caseSensitive: false,
    );
    final valueRegex = RegExp(
      "value\\s*=\\s*([\"'])(.*?)\\1|value\\s*=\\s*([^\\s>]+)",
      caseSensitive: false,
    );

    for (final match in optionRegex.allMatches(selectHtml)) {
      final attrs = match.group(1) ?? '';
      final text = _stripHtml(match.group(2) ?? '');
      final valueMatch = valueRegex.firstMatch(attrs);
      final rawValue =
          valueMatch?.group(2) ?? valueMatch?.group(3) ?? text.trim();
      final codeMatch = RegExp(r'20\d{3}').firstMatch(rawValue);
      final code = codeMatch?.group(0);
      if (code == null || code.isEmpty) {
        continue;
      }
      items.add(SemesterOption(code: code, name: text));
    }

    return items;
  }

  static String? _inferSemesterCodeFromHtml(String html) {
    final text = _stripHtml(html);
    final academicYearMatch = RegExp(
      r'(20\d{2})-(20\d{2})学年\s*第?([一二12])学期',
    ).firstMatch(text);
    if (academicYearMatch != null) {
      final startYear = academicYearMatch.group(1);
      final term = academicYearMatch.group(3);
      if (startYear != null && term != null) {
        final normalizedTerm = term == '一' || term == '1' ? '1' : '2';
        return '$startYear$normalizedTerm';
      }
    }

    final directCodeMatch = RegExp(
      "XNXQDM[\"':=\\s]+(20\\d{3})",
    ).firstMatch(html);
    return directCodeMatch?.group(1);
  }

  static String _formatFallbackSemesterName(String code) {
    if (!RegExp(r'^\d{5}$').hasMatch(code)) {
      return '';
    }
    final startYear = int.tryParse(code.substring(0, 4));
    final term = code.substring(4);
    if (startYear == null) {
      return '';
    }
    final label = term == '1' ? '第一学期' : '第二学期';
    return '${startYear}-${startYear + 1}学年 $label';
  }

  static String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
