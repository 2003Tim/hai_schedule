import 'package:hai_schedule/utils/app_logger.dart';
import 'package:hai_schedule/models/course.dart';

/// 海南大学课表解析器
class ScheduleParser {
  static const _weekdayMap = {
    '一': 1,
    '二': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '日': 7,
    '天': 7,
  };

  static const int _maxRawScheduleLength = 5000;
  static const int _maxSectionCount = 20;
  static final RegExp _slotPattern = RegExp(
    r'^\s*(.+?)\s*星期([一二三四五六日天])\s*\[(\d+)(?:\s*-\s*(\d+))?节\]\s*(.*)$',
  );

  /// 从 API JSON 响应解析课程列表
  static List<Course> parseApiResponse(Map<String, dynamic> jsonData) {
    final courses = <Course>[];
    final rows = _extractRows(jsonData);
    if (rows == null) return courses;

    for (final row in rows) {
      try {
        final course = _parseCourseRow(Map<String, dynamic>.from(row as Map));
        courses.add(course);
      } catch (e) {
        // ignore parse errors for individual courses
      }
    }
    return courses;
  }

  static DateTime? inferSemesterStart(
    Map<String, dynamic> jsonData, {
    String? semesterCode,
  }) {
    final rows = _extractRows(jsonData);
    if (rows == null) return null;

    final candidateCounts = <DateTime, int>{};
    for (final row in rows) {
      try {
        final candidate = _inferSemesterStartFromRow(
          Map<String, dynamic>.from(row as Map),
          semesterCode: semesterCode,
        );
        if (candidate == null) continue;
        candidateCounts.update(
          candidate,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      } catch (_) {
        continue;
      }
    }

    if (candidateCounts.isEmpty) return null;

    final rankedCandidates =
        candidateCounts.entries.toList()..sort((a, b) {
          final countCompare = b.value.compareTo(a.value);
          if (countCompare != 0) return countCompare;
          return a.key.compareTo(b.key);
        });
    return rankedCandidates.first.key;
  }

  static List<dynamic>? _extractRows(Map<String, dynamic> json) {
    final datas = json['datas'];
    if (datas is Map) {
      for (final value in datas.values) {
        if (value is Map && value['rows'] is List) {
          return value['rows'];
        }
      }
    }
    return null;
  }

  static Course _parseCourseRow(Map<String, dynamic> row) {
    final courseId = row['WID'] as String? ?? '';
    final courseName = row['KCMC'] as String? ?? '';
    final scheduleExpression = _scheduleExpressionFromRow(row);
    final slots = _parseScheduleSlots(scheduleExpression, courseId, courseName);

    return Course(
      id: courseId,
      code: row['KCDM'] as String? ?? '',
      name: courseName,
      className: row['BJMC'] as String? ?? '',
      teacher: row['RKJS'] as String? ?? '',
      college: row['KKDW_DISPLAY'] as String? ?? '',
      credits: (row['XF'] as num?)?.toDouble() ?? 0,
      totalHours: (row['ZXS'] as num?)?.toInt() ?? 0,
      semester: row['XNXQDM_DISPLAY'] as String? ?? '',
      campus: row['XQDM_DISPLAY'] as String? ?? '',
      teachingType: row['SKFSDM_DISPLAY'] as String? ?? '',
      slots: slots,
    );
  }

  static List<ScheduleSlot> _parseScheduleSlots(
    String rawSchedule,
    String courseId,
    String courseName,
  ) {
    if (rawSchedule.isEmpty) return [];
    if (rawSchedule.length > _maxRawScheduleLength) return [];
    final slotsByKey = <String, _SlotAccumulator>{};

    for (final segment in rawSchedule.split(RegExp(r'[;；]'))) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      try {
        final slot = _parseSingleSlot(trimmed, courseId, courseName);
        if (slot == null) continue;
        final key =
            '${slot.weekday}|${slot.startSection}|${slot.endSection}|${slot.location}';
        final accumulator = slotsByKey.putIfAbsent(
          key,
          () => _SlotAccumulator(slot),
        );
        accumulator.addWeekRanges(slot.weekRanges);
      } catch (e) {
        AppLogger.warn('ScheduleParser', '解析课程时间段失败: "$trimmed"', e);
      }
    }

    final slots = slotsByKey.values.map((item) => item.toSlot()).toList();
    slots.sort((a, b) {
      final weekdayCompare = a.weekday.compareTo(b.weekday);
      if (weekdayCompare != 0) return weekdayCompare;
      final sectionCompare = a.startSection.compareTo(b.startSection);
      if (sectionCompare != 0) return sectionCompare;
      return a.endSection.compareTo(b.endSection);
    });
    return slots;
  }

  static ScheduleSlot? _parseSingleSlot(
    String text,
    String courseId,
    String courseName,
  ) {
    final match = _slotPattern.firstMatch(text);
    if (match == null) return null;

    final weekStr = match.group(1)?.trim() ?? '';
    final weekday = _weekdayMap[match.group(2)]!;
    final startSection = int.parse(match.group(3)!);
    final endSection = int.parse(match.group(4) ?? match.group(3)!);

    // 节次范围校验：合法值为 1-20 节，且起始不得大于结束
    if (startSection < 1 ||
        startSection > _maxSectionCount ||
        endSection < 1 ||
        endSection > _maxSectionCount ||
        startSection > endSection) {
      return null;
    }

    final location = match.group(5)?.trim() ?? '';

    final weekRanges = _parseWeekRanges(weekStr);
    if (weekRanges.isEmpty) return null;

    return ScheduleSlot(
      courseId: courseId,
      courseName: courseName,
      weekday: weekday,
      startSection: startSection,
      endSection: endSection,
      location: location,
      weekRanges: weekRanges,
    );
  }

  static List<WeekRange> _parseWeekRanges(String weekStr) {
    final ranges = <WeekRange>[];
    final normalized = weekStr
        .replaceAll('，', ',')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('第', '')
        .replaceAll('教学周', '')
        .replaceAll('周次', '');

    for (final part in normalized.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final weekType =
          trimmed.contains('单')
              ? WeekType.odd
              : trimmed.contains('双')
              ? WeekType.even
              : WeekType.all;
      final cleaned = trimmed.replaceAll(RegExp(r'周|\(|\)|单|双'), '');
      if (cleaned.isEmpty) continue;

      if (cleaned.contains('-')) {
        final nums = cleaned.split('-');
        if (nums.length == 2) {
          final start = int.tryParse(nums[0].trim());
          final end = int.tryParse(nums[1].trim());
          // 周次范围校验：合法值为 1-53 周，且起始不得大于结束
          if (start != null &&
              end != null &&
              start >= 1 &&
              end <= 53 &&
              start <= end) {
            ranges.add(WeekRange(start: start, end: end, type: weekType));
          }
        }
      } else {
        final week = int.tryParse(cleaned);
        // 周次范围校验：合法值为 1-53 周
        if (week != null && week >= 1 && week <= 53) {
          ranges.add(WeekRange(start: week, end: week, type: weekType));
        }
      }
    }

    return _mergeWeekRanges(ranges);
  }

  static DateTime? _inferSemesterStartFromRow(
    Map<String, dynamic> row, {
    String? semesterCode,
  }) {
    final startText = row['SCSKRQ']?.toString().trim() ?? '';
    if (startText.isEmpty) return null;
    final startDate = DateTime.tryParse(startText);
    if (startDate == null) return null;

    final scheduleExpression = _scheduleExpressionFromRow(row);
    if (scheduleExpression.isEmpty) return null;
    final slots = _parseScheduleSlots(scheduleExpression, '', '');
    if (slots.isEmpty) return null;

    final occurrenceDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final alignedSlots =
        slots
            .where(
              (slot) =>
                  slot.weekday == occurrenceDate.weekday &&
                  slot.getAllActiveWeeks().isNotEmpty,
            )
            .toList();
    if (alignedSlots.isEmpty) return null;

    alignedSlots.sort((a, b) {
      final weekCompare = a.getAllActiveWeeks().first.compareTo(
        b.getAllActiveWeeks().first,
      );
      if (weekCompare != 0) return weekCompare;
      return a.weekday.compareTo(b.weekday);
    });

    final earliestSlot = alignedSlots.first;
    final earliestWeek = earliestSlot.getAllActiveWeeks().first;
    final candidate = occurrenceDate.subtract(
      Duration(days: (earliestWeek - 1) * 7 + (earliestSlot.weekday - 1)),
    );
    final normalizedCandidate = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
    );
    if (!_isPlausibleSemesterStart(normalizedCandidate, semesterCode)) {
      return null;
    }
    return normalizedCandidate;
  }

  static String _scheduleExpressionFromRow(Map<String, dynamic> row) {
    final withLocation = row['PKSJDD']?.toString().trim() ?? '';
    if (withLocation.isNotEmpty) return withLocation;
    return row['PKSJ']?.toString().trim() ?? '';
  }

  static List<WeekRange> _mergeWeekRanges(List<WeekRange> ranges) {
    if (ranges.isEmpty) return ranges;
    final sorted = [...ranges]..sort((a, b) {
      final typeCompare = a.type.index.compareTo(b.type.index);
      if (typeCompare != 0) return typeCompare;
      final startCompare = a.start.compareTo(b.start);
      if (startCompare != 0) return startCompare;
      return a.end.compareTo(b.end);
    });

    final merged = <WeekRange>[];
    for (final range in sorted) {
      if (merged.isEmpty) {
        merged.add(range);
        continue;
      }

      final previous = merged.last;
      if (previous.type == range.type && range.start <= previous.end + 1) {
        merged[merged.length - 1] = WeekRange(
          start: previous.start,
          end: range.end > previous.end ? range.end : previous.end,
          type: previous.type,
        );
        continue;
      }

      merged.add(range);
    }
    return merged;
  }

  static bool _isPlausibleSemesterStart(
    DateTime candidate,
    String? semesterCode,
  ) {
    if (semesterCode == null || semesterCode.length < 5) return true;

    final startYear = int.tryParse(semesterCode.substring(0, 4));
    final term = semesterCode.substring(4);
    if (startYear == null) return true;

    final earliest =
        term == '1' ? DateTime(startYear, 8, 1) : DateTime(startYear + 1, 2, 1);
    final latest =
        term == '1'
            ? DateTime(startYear, 10, 31)
            : DateTime(startYear + 1, 4, 30);
    return !candidate.isBefore(earliest) && !candidate.isAfter(latest);
  }
}

class _SlotAccumulator {
  _SlotAccumulator(this._baseSlot);

  final ScheduleSlot _baseSlot;
  final List<WeekRange> _weekRanges = <WeekRange>[];

  void addWeekRanges(List<WeekRange> ranges) {
    _weekRanges.addAll(ranges);
  }

  ScheduleSlot toSlot() {
    final mergedRanges = ScheduleParser._mergeWeekRanges(_weekRanges);
    return ScheduleSlot(
      courseId: _baseSlot.courseId,
      courseName: _baseSlot.courseName,
      teacher: _baseSlot.teacher,
      weekday: _baseSlot.weekday,
      startSection: _baseSlot.startSection,
      endSection: _baseSlot.endSection,
      location: _baseSlot.location,
      weekRanges: mergedRanges,
    );
  }
}
