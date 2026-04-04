import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/school_time.dart';

void main() {
  group('ClassTime._timeToMinutes', () {
    test('parses valid HH:MM time correctly', () {
      final ct = ClassTime(section: 1, startTime: '07:40', endTime: '08:25');
      expect(ct.startMinutes, 7 * 60 + 40);
      expect(ct.endMinutes, 8 * 60 + 25);
    });

    test('returns 0 for empty string', () {
      final ct = ClassTime(section: 1, startTime: '', endTime: '');
      expect(ct.startMinutes, 0);
      expect(ct.endMinutes, 0);
    });

    test('returns 0 for single-part string without colon', () {
      final ct = ClassTime(section: 1, startTime: '740', endTime: '825');
      expect(ct.startMinutes, 0);
      expect(ct.endMinutes, 0);
    });

    test('returns 0 for non-numeric parts', () {
      final ct = ClassTime(section: 1, startTime: 'ab:cd', endTime: 'ef:gh');
      expect(ct.startMinutes, 0);
      expect(ct.endMinutes, 0);
    });

    test('returns 0 for partially numeric parts', () {
      final ct = ClassTime(section: 1, startTime: '7:xx', endTime: 'xx:40');
      expect(ct.startMinutes, 7 * 60);
      expect(ct.endMinutes, 40);
    });
  });

  group('ClassTime.fromJson', () {
    test('parses valid JSON correctly', () {
      final ct = ClassTime.fromJson({
        'section': 3,
        'startTime': '09:45',
        'endTime': '10:30',
      });
      expect(ct.section, 3);
      expect(ct.startTime, '09:45');
      expect(ct.endTime, '10:30');
    });

    test('handles double section value (e.g. 1.0 from JSON decoder)', () {
      final ct = ClassTime.fromJson({
        'section': 1.0,
        'startTime': '07:40',
        'endTime': '08:25',
      });
      expect(ct.section, 1);
    });

    test('falls back to 0 when section is null', () {
      final ct = ClassTime.fromJson({
        'section': null,
        'startTime': '07:40',
        'endTime': '08:25',
      });
      expect(ct.section, 0);
    });

    test('falls back to "00:00" when startTime is null', () {
      final ct = ClassTime.fromJson({
        'section': 1,
        'startTime': null,
        'endTime': '08:25',
      });
      expect(ct.startTime, '00:00');
    });

    test('falls back to "00:00" when endTime is null', () {
      final ct = ClassTime.fromJson({
        'section': 1,
        'startTime': '07:40',
        'endTime': null,
      });
      expect(ct.endTime, '00:00');
    });

    test('falls back to "00:00" when startTime key is missing', () {
      final ct = ClassTime.fromJson({'section': 1, 'endTime': '08:25'});
      expect(ct.startTime, '00:00');
    });
  });

  group('SchoolTimeConfig', () {
    test('getClassTime returns null for out-of-range section', () {
      final config = SchoolTimeConfig.hainanuDefault();
      expect(config.getClassTime(0), isNull);
      expect(config.getClassTime(config.totalSections + 1), isNull);
    });

    test('getClassTime returns correct entry for valid section', () {
      final config = SchoolTimeConfig.hainanuDefault();
      final ct = config.getClassTime(1);
      expect(ct, isNotNull);
      expect(ct!.startTime, '07:40');
    });

    test('fromJson round-trips with toJson', () {
      final original = SchoolTimeConfig.hainanuDefault();
      final restored = SchoolTimeConfig.fromJson(original.toJson());
      expect(restored.classTimes.length, original.classTimes.length);
      expect(restored.classTimes.first.startTime, original.classTimes.first.startTime);
    });
  });
}
