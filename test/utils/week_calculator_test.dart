import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/utils/week_calculator.dart';

void main() {
  group('WeekCalculator', () {
    test('infers fall semester when current date is in autumn', () {
      expect(WeekCalculator.inferSemesterCode(DateTime(2026, 9, 15)), '20261');

      final calculator = WeekCalculator.hainanuSemester(
        null,
        now: DateTime(2026, 9, 15),
      );

      expect(calculator.semesterStart, DateTime(2026, 9, 7));
    });

    test('infers spring semester when current date is in spring term', () {
      expect(WeekCalculator.inferSemesterCode(DateTime(2026, 4, 7)), '20252');

      final calculator = WeekCalculator.hainanuSemester(
        null,
        now: DateTime(2026, 4, 7),
      );

      expect(calculator.semesterStart, DateTime(2026, 3, 2));
    });

    test(
      'falls back with current-date inference for invalid semester code',
      () {
        final calculator = WeekCalculator.hainanuSemester(
          'invalid',
          now: DateTime(2026, 10, 3),
        );

        expect(calculator.semesterStart, DateTime(2026, 9, 7));
      },
    );
  });
}
