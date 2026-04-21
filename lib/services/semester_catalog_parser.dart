import 'dart:convert';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/services/catalog_parsing_exception.dart';
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
        options.addAll(_parseOptionTags(selectHtml, fallbackNow: fallbackNow));
      }
    } catch (_) {
      // Fall through to the semester-code fallback below.
    }

    final normalized = normalize(options);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    throw const CatalogParsingException();
  }

  static List<SemesterOption> _parseOptionTags(
    String selectHtml, {
    DateTime? fallbackNow,
  }) {
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
      final rawValueCandidate =
          valueMatch?.group(2) ?? valueMatch?.group(3) ?? '';
      final rawValue =
          rawValueCandidate.trim().isEmpty ? text.trim() : rawValueCandidate;
      final code = _extractSemesterCode(rawValue, fallbackNow: fallbackNow);
      if (code == null || code.isEmpty) {
        continue;
      }
      items.add(SemesterOption(code: code, name: text));
    }

    return items;
  }

  static String? _extractSemesterCode(String raw, {DateTime? fallbackNow}) {
    final directCodeMatch = RegExp(r'20\d{3}').firstMatch(raw);
    if (directCodeMatch != null) {
      return directCodeMatch.group(0);
    }

    final text = _stripHtml(raw);
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

    final htmlCodeMatch = RegExp("XNXQDM[\"':=\\s]+(20\\d{3})").firstMatch(raw);
    if (htmlCodeMatch != null) {
      return htmlCodeMatch.group(1);
    }

    final shouldFallback =
        text.contains('学期') && !text.contains('请选择') && !text.contains('切换');
    if (!shouldFallback) {
      return null;
    }

    final fallbackCode = WeekCalculator.inferSemesterCode(
      fallbackNow ?? DateTime.now(),
    );
    return RegExp(r'^\d{5}$').hasMatch(fallbackCode) ? fallbackCode : null;
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
