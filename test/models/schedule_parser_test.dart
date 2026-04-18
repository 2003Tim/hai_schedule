import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/schedule_parser.dart';

void main() {
  test('ScheduleParser merges split week segments for the same slot', () {
    final courses = ScheduleParser.parseApiResponse(_samplePayload());

    expect(courses, hasLength(1));
    final course = courses.single;
    expect(course.slots, hasLength(3));

    final mondayMorning = course.slots.firstWhere(
      (slot) =>
          slot.weekday == DateTime.monday &&
          slot.startSection == 1 &&
          slot.endSection == 2,
    );
    expect(mondayMorning.getAllActiveWeeks(), <int>[
      3,
      4,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
    ]);

    final mondaySpecial = course.slots.firstWhere(
      (slot) =>
          slot.weekday == DateTime.monday &&
          slot.startSection == 3 &&
          slot.endSection == 6,
    );
    expect(mondaySpecial.getAllActiveWeeks(), <int>[20]);

    final tuesdaySpecial = course.slots.firstWhere(
      (slot) =>
          slot.weekday == DateTime.tuesday &&
          slot.startSection == 2 &&
          slot.endSection == 5,
    );
    expect(tuesdaySpecial.getAllActiveWeeks(), <int>[20]);
  });

  test(
    'ScheduleParser infers semester start from first class date and week',
    () {
      final semesterStart = ScheduleParser.inferSemesterStart(
        _samplePayload(),
        semesterCode: '20251',
      );

      expect(semesterStart, DateTime(2025, 9, 8));
    },
  );

  test('ScheduleParser supports odd-week rules and single-section slots', () {
    final courses = ScheduleParser.parseApiResponse({
      'datas': {
        'cxkb': {
          'rows': [
            {
              'WID': 'odd-course',
              'KCMC': '离散数学',
              'KCDM': 'SX1001',
              'BJMC': '测试班级',
              'RKJS': '张老师',
              'KKDW_DISPLAY': '计算机科学与技术学院',
              'XF': 2.0,
              'ZXS': 32.0,
              'XNXQDM_DISPLAY': '2025-2026学年 第一学期',
              'XQDM_DISPLAY': '海甸校区',
              'SKFSDM_DISPLAY': '讲授',
              'PKSJDD': '3-15周(单) 星期三[3节](海甸)4-201',
            },
          ],
        },
      },
    });

    final slot = courses.single.slots.single;
    expect(slot.weekday, DateTime.wednesday);
    expect(slot.startSection, 3);
    expect(slot.endSection, 3);
    expect(slot.getAllActiveWeeks(), <int>[3, 5, 7, 9, 11, 13, 15]);
  });

  test(
    'ScheduleParser infers semester start even when a course starts in week 5',
    () {
      final semesterStart = ScheduleParser.inferSemesterStart({
        'datas': {
          'cxkb': {
            'rows': [
              {
                'WID': 'week-5-course',
                'KCMC': '机器学习导论',
                'SCSKRQ': '2025-10-06',
                'PKSJDD': '5-8周 星期一[1-2节](海甸)3-203',
              },
            ],
          },
        },
      }, semesterCode: '20251');

      expect(semesterStart, DateTime(2025, 9, 8));
    },
  );

  test(
    'ScheduleParser ignores rows when SCSKRQ weekday does not match any parsed slot',
    () {
      final semesterStart = ScheduleParser.inferSemesterStart({
        'datas': {
          'cxkb': {
            'rows': [
              {
                'WID': 'bad-row',
                'KCMC': '异常数据课程',
                'SCSKRQ': '2025-09-22',
                'PKSJDD': '3-4周 星期二[1-2节](海甸)1-101',
              },
            ],
          },
        },
      }, semesterCode: '20251');

      expect(semesterStart, isNull);
    },
  );
}

Map<String, dynamic> _samplePayload() {
  return {
    'datas': {
      'cxkb': {
        'rows': [
          {
            'JXERM': null,
            'SKFSDM': '01',
            'XDFSDM': '0',
            'KSSJMS': null,
            'KKDW_DISPLAY': '计算机科学与技术学院',
            'PKDD': '(海甸)2-106,(海甸)5-102',
            'SCSKRQ': '2025-09-22',
            'XQDM_DISPLAY': '海甸校区',
            'XKBZ': null,
            'XSJXFSBZ': null,
            'KSDDMS': null,
            'XNXQDM': '20251',
            'BY10': null,
            'YXYWMC':
                'School of Computer Science and Technology (International School of Digital Media and Film)',
            'WID': '836080d7e7dc47be9f1ebb37fc6e09c8',
            'XNXQDM_DISPLAY': '2025-2026学年 第一学期',
            'KCXZDM': '1',
            'PKSJ':
                '3-4,6-7周 星期一[1-2节];8-11周 星期一[1-2节];12-15周 星期一[1-2节];20周 星期一[3-6节];20周 星期二[2-5节]',
            'BY2': null,
            'BY1': '0',
            'BY4': null,
            'BY3': null,
            'XSJXFSDM_DISPLAY': '',
            'BY6': null,
            'SKXS_DISPLAY': '本校常规授课',
            'BY5': null,
            'BY8': null,
            'BY7': null,
            'BJMC': '人工智能25计科6选3',
            'RZLBDM': null,
            'KCDM': 'SX81232007',
            'BY9': null,
            'KCMCYW': null,
            'DZ_SCU_EWMFJ': null,
            'YAPXS': 32,
            'KBBZ': null,
            'KCMC': '人工智能',
            'SKFSDM_DISPLAY': '讲授',
            'BJDM': '20251-1016-SX81232007-1756373181841',
            'KKDW': '1016',
            'XSJXFSDM': null,
            'ZXS': 32.0,
            'PKSJDD':
                '3-4,6-7周 星期一[1-2节](海甸)2-106;8-11周 星期一[1-2节](海甸)2-106;12-15周 星期一[1-2节](海甸)2-106;20周 星期一[3-6节](海甸)5-102;20周 星期二[2-5节](海甸)5-102',
            'XKRS': '28',
            'RKJS': '齐琦,李华,白晓东,张志才',
            'KCFLDM': '1',
            'XQDM': '3',
            'XF': 2.0,
            'XH': '25210812000024',
            'ORDERFILTER': null,
            'XNXQYWMC': null,
            'SKXS': '1',
          },
        ],
      },
    },
  };
}
