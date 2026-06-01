import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/models/school_time.dart';

class UndergraduateScheduleParseResult {
  const UndergraduateScheduleParseResult({
    required this.courses,
    required this.semesterCode,
    required this.semesterOptions,
    required this.schoolTimeConfig,
  });

  final List<Course> courses;
  final String semesterCode;
  final List<SemesterOption> semesterOptions;
  final SchoolTimeConfig schoolTimeConfig;
}

class UndergraduateScheduleParser {
  UndergraduateScheduleParser._();

  static final RegExp _semesterPattern = RegExp(
    r'^(20\d{2})-(20\d{2})-([12])$',
  );
  static final RegExp _sectionPattern = RegExp(r'\(([^)]*小节)\)');
  static final RegExp _timePattern = RegExp(
    r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})',
  );
  static final RegExp _bracketSectionPattern = RegExp(r'\[([^\]]+)节\]');

  static String? normalizeSemesterCode(String value) {
    final normalized = value.trim();
    if (RegExp(r'^\d{4}[12]$').hasMatch(normalized)) {
      return normalized;
    }
    final match = _semesterPattern.firstMatch(normalized);
    if (match == null) return null;
    return '${match.group(1)}${match.group(3)}';
  }

  static UndergraduateScheduleParseResult parseHtml(String html) {
    final document = html_parser.parse(html);
    final selectedSemester = _selectedSemesterValue(document);
    final semesterCode =
        normalizeSemesterCode(selectedSemester) ??
        normalizeSemesterCode(
          document.querySelector('#xnxq01id option')?.attributes['value'] ?? '',
        ) ??
        '';
    final semesterOptions = _parseSemesterOptions(document);
    final schoolTimeConfig = _parseSchoolTimeConfig(document);
    final rows = _parseTimeRows(document);
    final metadataByName = _parseCourseMetadata(document);
    final courses = _parseCourses(
      document: document,
      semesterValue: selectedSemester,
      semesterCode: semesterCode,
      timeRows: rows,
      metadataByName: metadataByName,
    );

    return UndergraduateScheduleParseResult(
      courses: courses,
      semesterCode: semesterCode,
      semesterOptions: semesterOptions,
      schoolTimeConfig: schoolTimeConfig,
    );
  }

  static String _selectedSemesterValue(dom.Document document) {
    final selected = document.querySelector('#xnxq01id option[selected]');
    if (selected != null) {
      return selected.attributes['value']?.trim() ?? selected.text.trim();
    }
    final select = document.querySelector('#xnxq01id');
    return select?.attributes['value']?.trim() ??
        document
            .querySelector('#xnxq01id option')
            ?.attributes['value']
            ?.trim() ??
        '';
  }

  static List<SemesterOption> _parseSemesterOptions(dom.Document document) {
    return document
        .querySelectorAll('#xnxq01id option')
        .map((option) {
          final value = option.attributes['value']?.trim() ?? '';
          final code = normalizeSemesterCode(value);
          if (code == null) return null;
          return SemesterOption(code: code, name: option.text.trim());
        })
        .whereType<SemesterOption>()
        .toList(growable: false);
  }

  static SchoolTimeConfig _parseSchoolTimeConfig(dom.Document document) {
    final rows = _parseTimeRows(document);
    final bySection = <int, ClassTime>{};
    for (final row in rows) {
      if (row.startTime.isEmpty || row.endTime.isEmpty) continue;
      for (final section in row.sections) {
        bySection[section] = ClassTime(
          section: section,
          startTime: row.startTime,
          endTime: row.endTime,
        );
      }
    }
    if (bySection.isEmpty) {
      return SchoolTimeConfig.hainanuDefault();
    }
    final maxSection = bySection.keys.reduce((a, b) => a > b ? a : b);
    final defaults = SchoolTimeConfig.hainanuDefault();
    final classTimes = <ClassTime>[];
    for (var section = 1; section <= maxSection; section++) {
      classTimes.add(
        bySection[section] ??
            defaults.getClassTime(section) ??
            ClassTime(section: section, startTime: '00:00', endTime: '00:00'),
      );
    }
    return SchoolTimeConfig(name: '海南大学本科', classTimes: classTimes);
  }

  static List<_TimeRow> _parseTimeRows(dom.Document document) {
    final rows = document.querySelectorAll('#timetable tr');
    final result = <_TimeRow>[];
    for (var index = 1; index < rows.length; index++) {
      final header =
          rows[index].children.isEmpty
              ? ''
              : _clean(rows[index].children.first.text);
      final sectionMatch = _sectionPattern.firstMatch(header);
      final timeMatch = _timePattern.firstMatch(header);
      if (sectionMatch == null) continue;
      final sections = _numbers(sectionMatch.group(1) ?? '');
      if (sections.isEmpty) continue;
      result.add(
        _TimeRow(
          rowIndex: index,
          sections: sections,
          startTime: timeMatch?.group(1) ?? '',
          endTime: timeMatch?.group(2) ?? '',
        ),
      );
    }
    return result;
  }

  static Map<String, _CourseMetadata> _parseCourseMetadata(
    dom.Document document,
  ) {
    final result = <String, _CourseMetadata>{};
    final rows = document.querySelectorAll('#dataTables2 tr');
    if (rows.length < 3) return result;
    for (final row in rows.skip(2)) {
      final cells = row.children.map((cell) => _clean(cell.text)).toList();
      if (cells.length < 5) continue;
      final name = cells[3];
      if (name.isEmpty) continue;
      result[name] = _CourseMetadata(
        className: cells.length > 1 ? cells[1] : '',
        code: cells.length > 2 ? cells[2] : '',
        teacher: cells.length > 4 ? cells[4] : '',
        teachingType: cells.length > 7 ? cells[7] : '',
      );
    }
    return result;
  }

  static List<Course> _parseCourses({
    required dom.Document document,
    required String semesterValue,
    required String semesterCode,
    required List<_TimeRow> timeRows,
    required Map<String, _CourseMetadata> metadataByName,
  }) {
    final timeRowByIndex = {for (final row in timeRows) row.rowIndex: row};
    final timetableRows = document.querySelectorAll('#timetable tr');
    final byCourse = <String, Course>{};

    for (var rowIndex = 1; rowIndex < timetableRows.length; rowIndex++) {
      final timeRow = timeRowByIndex[rowIndex];
      if (timeRow == null) continue;
      final cells = timetableRows[rowIndex].children;
      for (var cellIndex = 1; cellIndex < cells.length; cellIndex++) {
        final weekday = cellIndex;
        final blocks = cells[cellIndex]
            .querySelectorAll('.kbcontent')
            .where((block) => _clean(block.text).isNotEmpty)
            .where(
              (block) =>
                  !(block.attributes['style'] ?? '').contains('display:none'),
            );

        for (final block in blocks) {
          final parsed = _parseCourseBlock(
            block: block,
            semesterValue: semesterValue,
            semesterCode: semesterCode,
            weekday: weekday,
            timeRow: timeRow,
            metadataByName: metadataByName,
          );
          if (parsed == null) continue;
          final existing = byCourse[parsed.id];
          if (existing == null) {
            byCourse[parsed.id] = parsed;
          } else {
            byCourse[parsed.id] = Course(
              id: existing.id,
              code: existing.code,
              name: existing.name,
              className: existing.className,
              teacher: existing.teacher,
              college: existing.college,
              credits: existing.credits,
              totalHours: existing.totalHours,
              semester: existing.semester,
              campus: existing.campus,
              teachingType: existing.teachingType,
              slots: [...existing.slots, ...parsed.slots],
            );
          }
        }
      }
    }

    return byCourse.values.toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  static Course? _parseCourseBlock({
    required dom.Element block,
    required String semesterValue,
    required String semesterCode,
    required int weekday,
    required _TimeRow timeRow,
    required Map<String, _CourseMetadata> metadataByName,
  }) {
    final fonts = block.querySelectorAll('font');
    if (fonts.isEmpty) return null;
    final name = _clean(
      fonts
          .where(
            (font) =>
                (font.attributes['title'] ?? '').isEmpty &&
                (font.attributes['name'] ?? '').isEmpty,
          )
          .map((font) => font.text)
          .firstWhere((text) => _clean(text).isNotEmpty, orElse: () => ''),
    );
    if (name.isEmpty) return null;

    final teacher = _clean(
      _textByTitle(fonts, '教师'),
    ).replaceAll(RegExp(r'\(\)$'), '');
    final scheduleText = _clean(_textByTitle(fonts, '周次(节次)'));
    final location = _clean(_textByTitle(fonts, '教室'));
    final noticeId = _clean(
      _textByTitle(fonts, '通知单编号'),
    ).replaceFirst('通知单编号：', '');
    final metadata = metadataByName[name];
    final id =
        noticeId.isNotEmpty
            ? noticeId
            : '$semesterCode|$name|$teacher|$weekday|$scheduleText|$location';
    final sectionNumbers = _sectionNumbers(scheduleText);
    final startSection =
        sectionNumbers.isNotEmpty
            ? sectionNumbers.first
            : timeRow.sections.first;
    final endSection =
        sectionNumbers.isNotEmpty ? sectionNumbers.last : timeRow.sections.last;
    final weekRanges = _parseWeekRanges(scheduleText);
    if (weekRanges.isEmpty) return null;

    final slot = ScheduleSlot(
      courseId: id,
      courseName: name,
      teacher: teacher,
      weekday: weekday,
      startSection: startSection,
      endSection: endSection,
      location: location,
      weekRanges: weekRanges,
    );

    return Course(
      id: id,
      code: metadata?.code ?? '',
      name: name,
      className: metadata?.className ?? '',
      teacher: teacher.isNotEmpty ? teacher : metadata?.teacher ?? '',
      college: '',
      credits: 0,
      totalHours: 0,
      semester: semesterValue.isNotEmpty ? semesterValue : semesterCode,
      campus: _campusFromLocation(location),
      teachingType: metadata?.teachingType ?? '',
      slots: [slot],
    );
  }

  static String _textByTitle(List<dom.Element> fonts, String title) {
    return fonts
        .where((font) => font.attributes['title'] == title)
        .map((font) => font.text)
        .firstWhere((text) => _clean(text).isNotEmpty, orElse: () => '');
  }

  static List<int> _sectionNumbers(String scheduleText) {
    final match = _bracketSectionPattern.firstMatch(scheduleText);
    if (match == null) return const [];
    return _numbers(match.group(1) ?? '');
  }

  static List<WeekRange> _parseWeekRanges(String scheduleText) {
    final beforeWeek = scheduleText.split('周').first;
    final normalized =
        beforeWeek
            .replaceAll('(', '')
            .replaceAll(')', '')
            .replaceAll('（', '')
            .replaceAll('）', '')
            .replaceAll('第', '')
            .trim();
    final ranges = <WeekRange>[];
    for (final rawPart in normalized.split(RegExp(r'[、,，;；]'))) {
      final part = rawPart.trim();
      if (part.isEmpty) continue;
      final type =
          part.contains('单')
              ? WeekType.odd
              : part.contains('双')
              ? WeekType.even
              : WeekType.all;
      final values = _numbers(part);
      if (values.isEmpty) continue;
      if (part.contains('-') && values.length >= 2) {
        ranges.add(WeekRange(start: values.first, end: values[1], type: type));
      } else {
        ranges.add(
          WeekRange(start: values.first, end: values.first, type: type),
        );
      }
    }
    return ranges;
  }

  static List<int> _numbers(String value) {
    return RegExp(r'\d+')
        .allMatches(value)
        .map((match) => int.tryParse(match.group(0) ?? ''))
        .whereType<int>()
        .toList(growable: false);
  }

  static String _campusFromLocation(String location) {
    final match = RegExp(r'^\(([^)]+)\)').firstMatch(location);
    return match?.group(1) ?? '';
  }

  static String _clean(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _TimeRow {
  const _TimeRow({
    required this.rowIndex,
    required this.sections,
    required this.startTime,
    required this.endTime,
  });

  final int rowIndex;
  final List<int> sections;
  final String startTime;
  final String endTime;
}

class _CourseMetadata {
  const _CourseMetadata({
    required this.className,
    required this.code,
    required this.teacher,
    required this.teachingType,
  });

  final String className;
  final String code;
  final String teacher;
  final String teachingType;
}
