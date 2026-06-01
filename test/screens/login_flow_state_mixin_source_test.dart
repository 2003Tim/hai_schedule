// #T1: previous contents of this file asserted on raw source text via
// `File(...).readAsStringSync() + contains(...)`. Such "tests" never
// compile, never run, and never fail when the implementation is refactored
// in semantically-equivalent ways. They were deleted.
//
// The behavioural coverage for [LoginFlowStateMixin] is being added
// incrementally as mixin methods are extracted into pure-Dart helpers
// that can be unit-tested without a Flutter widget harness. In the
// meantime, the foundation type [ScheduleSource] is now covered here
// since it underpins the mixin's source-routing logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:hai_schedule/models/schedule_source.dart';

void main() {
  group('ScheduleSource.fromValue', () {
    test('returns graduate for null', () {
      expect(ScheduleSource.fromValue(null), ScheduleSource.graduate);
    });

    test('returns graduate for empty string', () {
      expect(ScheduleSource.fromValue(''), ScheduleSource.graduate);
    });

    test('returns graduate for whitespace-only string', () {
      expect(ScheduleSource.fromValue('   '), ScheduleSource.graduate);
    });

    test('returns graduate for unknown value (silent fallback)', () {
      expect(ScheduleSource.fromValue('unknown'), ScheduleSource.graduate);
      expect(ScheduleSource.fromValue('grad'), ScheduleSource.graduate);
    });

    test('recognises undergraduate case-insensitively and trimmed', () {
      expect(ScheduleSource.fromValue('undergraduate'), ScheduleSource.undergraduate);
      expect(ScheduleSource.fromValue('UNDERGRADUATE'), ScheduleSource.undergraduate);
      expect(ScheduleSource.fromValue(' undergraduate '), ScheduleSource.undergraduate);
    });

    test('recognises graduate explicitly', () {
      expect(ScheduleSource.fromValue('graduate'), ScheduleSource.graduate);
      expect(ScheduleSource.fromValue('GRADUATE'), ScheduleSource.graduate);
    });
  });

  group('ScheduleSource predicates', () {
    test('isGraduate / isUndergraduate are mutually exclusive', () {
      for (final s in ScheduleSource.values) {
        expect(s.isGraduate, isNot(s.isUndergraduate));
      }
    });

    test('value string is stable and not empty', () {
      for (final s in ScheduleSource.values) {
        expect(s.value, isNotEmpty);
        // Persisted values must round-trip through fromValue.
        expect(ScheduleSource.fromValue(s.value), s);
      }
    });
  });
}
