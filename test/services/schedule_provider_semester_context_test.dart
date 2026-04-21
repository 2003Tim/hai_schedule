import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/schedule_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppStorage.instance.resetForTesting();
  });

  test(
    'ScheduleProvider uses inferred semester start from imported payload',
    () async {
      final provider = ScheduleProvider();
      await provider.ready;

      await provider.importFromJson(
        jsonEncode(_samplePayload()),
        semesterCode: '20251',
      );

      expect(provider.weekCalc.semesterStart, DateTime(2025, 9, 8));
      expect(provider.weekCalc.getWeekNumber(DateTime(2025, 9, 22)), 3);

      final mondaySlots = provider.getDisplaySlotsForDay(3, DateTime.monday);
      expect(
        mondaySlots.any(
          (slot) =>
              slot.isActive &&
              slot.slot.startSection == 1 &&
              slot.slot.endSection == 2,
        ),
        isTrue,
      );
    },
  );

  test('goToToday jumps when date is inside the active semester', () async {
    final provider = ScheduleProvider();
    await provider.ready;

    await provider.createSemester('20251');
    provider.selectWeek(1);

    final result = provider.goToToday(DateTime(2025, 9, 22));

    expect(result, ScheduleTodayNavigationResult.success);
    expect(provider.currentWeek, 4);
    expect(provider.selectedWeek, 4);
  });

  test(
    'goToToday keeps position when date is outside the active semester',
    () async {
      final provider = ScheduleProvider();
      await provider.ready;

      await provider.createSemester('20251');
      provider.selectWeek(5);

      final result = provider.goToToday(DateTime(2026, 2, 1));

      expect(result, ScheduleTodayNavigationResult.outOfRange);
      expect(provider.selectedWeek, 5);
    },
  );

  test(
    'merging semester catalog does not create semester containers implicitly',
    () async {
      final provider = ScheduleProvider();
      await provider.ready;

      await provider.mergeKnownSemesterOptions(const <SemesterOption>[
        SemesterOption(code: '20251', name: '2025-2026学年 第一学期'),
        SemesterOption(code: '20252', name: '2025-2026学年 第二学期'),
      ]);

      expect(provider.availableSemesterCodes, isEmpty);
      expect(provider.knownSemesterCatalog, hasLength(2));
      expect(provider.availableSemesterOptions.map((item) => item.code), [
        '20252',
        '20251',
      ]);
    },
  );
}

Map<String, dynamic> _samplePayload() {
  return {
    'datas': {
      'cxkb': {
        'rows': [
          {
            'WID': '836080d7e7dc47be9f1ebb37fc6e09c8',
            'KCMC': '人工智能',
            'KCDM': 'SX81232007',
            'BJMC': '人工智能25计科6选3',
            'RKJS': '齐琦,李华,白晓东,张志才',
            'KKDW_DISPLAY': '计算机科学与技术学院',
            'XF': 2.0,
            'ZXS': 32.0,
            'XNXQDM_DISPLAY': '2025-2026学年 第一学期',
            'XQDM_DISPLAY': '海甸校区',
            'SKFSDM_DISPLAY': '讲授',
            'SCSKRQ': '2025-09-22',
            'PKSJ':
                '3-4,6-7周 星期一[1-2节];8-11周 星期一[1-2节];12-15周 星期一[1-2节];20周 星期一[3-6节];20周 星期二[2-5节]',
            'PKSJDD':
                '3-4,6-7周 星期一[1-2节](海甸)2-106;8-11周 星期一[1-2节](海甸)2-106;12-15周 星期一[1-2节](海甸)2-106;20周 星期一[3-6节](海甸)5-102;20周 星期二[2-5节](海甸)5-102',
          },
        ],
      },
    },
  };
}
