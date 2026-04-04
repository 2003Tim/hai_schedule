import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/utils/app_storage_codec.dart';

void main() {
  group('AppStorageCodec', () {
    test('skips malformed mirrored course entries', () {
      final courses = AppStorageCodec.decodeGlobalCourseMirror([
        '{"id":"1","code":"MATH001","name":"高等数学","slots":[]}',
        'not-json',
      ]);

      expect(courses, hasLength(1));
      expect(courses.single.code, 'MATH001');
    });

    test('returns empty archive map for malformed json', () {
      expect(AppStorageCodec.decodeScheduleArchiveMap('not-json'), isEmpty);
    });

    test('tolerates invalid override enums and broken items', () {
      final overrides = AppStorageCodec.decodeScheduleOverrides('''
[
  {
    "id": "o1",
    "semesterCode": "20252",
    "dateKey": "2026-03-01",
    "weekday": 1,
    "startSection": 1,
    "endSection": 2,
    "type": "unknown",
    "status": "missing"
  },
  "bad-item"
]
''');

      expect(overrides, hasLength(1));
      expect(overrides.single.type.name, 'add');
      expect(overrides.single.status.name, 'normal');
    });
  });
}
