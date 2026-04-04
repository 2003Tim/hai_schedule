import 'package:hai_schedule/utils/app_logger.dart';
import 'package:hai_schedule/models/course.dart';

/// 海南大学课表解析器
class ScheduleParser {
  static const _weekdayMap = {
    '一': 1, '二': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '日': 7, '天': 7,
  };

  static const int _maxRawScheduleLength = 5000;
  static const int _maxSectionCount = 20;

  /// 从 API JSON 响应解析课程列表
  static List<Course> parseApiResponse(Map<String, dynamic> jsonData) {
    final courses = <Course>[];
    final rows = _extractRows(jsonData);
    if (rows == null) return courses;

    for (final row in rows) {
      try {
        final course = _parseCourseRow(row);
        courses.add(course);
      } catch (e) {
        // ignore parse errors for individual courses
      }
    }
    return courses;
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
    final pksjdd = row['PKSJDD'] as String? ?? '';
    final slots = _parseScheduleSlots(pksjdd, courseId, courseName);

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
    String pksjdd, String courseId, String courseName,
  ) {
    if (pksjdd.isEmpty) return [];
    if (pksjdd.length > _maxRawScheduleLength) return [];
    final slots = <ScheduleSlot>[];

    for (final segment in pksjdd.split(';')) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      try {
        final slot = _parseSingleSlot(trimmed, courseId, courseName);
        if (slot != null) slots.add(slot);
      } catch (e) {
        AppLogger.warn('ScheduleParser', '解析课程时间段失败: "$trimmed"', e);
      }
    }
    return slots;
  }

  static ScheduleSlot? _parseSingleSlot(
    String text, String courseId, String courseName,
  ) {
    final weekMatch = RegExp(r'^(.+?周)\s*').firstMatch(text);
    if (weekMatch == null) return null;
    final weekStr = weekMatch.group(1)!;

    final dayMatch = RegExp(r'星期([一二三四五六日天])').firstMatch(text);
    if (dayMatch == null) return null;
    final weekday = _weekdayMap[dayMatch.group(1)]!;

    final sectionMatch = RegExp(r'\[(\d+)-(\d+)节\]').firstMatch(text);
    if (sectionMatch == null) return null;
    final startSection = int.parse(sectionMatch.group(1)!);
    final endSection = int.parse(sectionMatch.group(2)!);

    // 节次范围校验：合法值为 1-20 节，且起始不得大于结束
    if (startSection < 1 || startSection > _maxSectionCount ||
        endSection < 1 || endSection > _maxSectionCount ||
        startSection > endSection) {
      return null;
    }

    final locationStart = sectionMatch.end;
    final location =
        locationStart < text.length ? text.substring(locationStart).trim() : '';

    final weekRanges = _parseWeekRanges(weekStr);

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

    WeekType weekType = WeekType.all;
    if (weekStr.contains('单')) {
      weekType = WeekType.odd;
    } else if (weekStr.contains('双')) {
      weekType = WeekType.even;
    }

    final cleaned = weekStr
        .replaceAll('单周', '')
        .replaceAll('双周', '')
        .replaceAll('周', '')
        .trim();

    for (final part in cleaned.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.contains('-')) {
        final nums = trimmed.split('-');
        if (nums.length == 2) {
          final start = int.tryParse(nums[0].trim());
          final end = int.tryParse(nums[1].trim());
          // 周次范围校验：合法值为 1-53 周，且起始不得大于结束
          if (start != null && end != null &&
              start >= 1 && end <= 53 && start <= end) {
            ranges.add(WeekRange(start: start, end: end, type: weekType));
          }
        }
      } else {
        final week = int.tryParse(trimmed);
        // 周次范围校验：合法值为 1-53 周
        if (week != null && week >= 1 && week <= 53) {
          ranges.add(WeekRange(start: week, end: week, type: weekType));
        }
      }
    }
    return ranges;
  }
}
