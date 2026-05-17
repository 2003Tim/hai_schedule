import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android native sync text contains no known mojibake fragments', () {
    final files = <String>[
      'android/app/src/main/kotlin/com/hainanu/hai_schedule/AutoSyncScheduler.kt',
      'android/app/src/main/kotlin/com/hainanu/hai_schedule/ScheduleNativeParser.kt',
      'android/app/src/main/kotlin/com/hainanu/hai_schedule/MainActivity.kt',
    ];
    const fragments = <String>[
      '涓嶈兘涓虹┖',
      '璇捐〃',
      '鏂板',
      '绉婚櫎',
      '璋冩暣',
      '锛',
      '宸插悓姝',
    ];

    for (final file in files) {
      final text = File(file).readAsStringSync();
      for (final fragment in fragments) {
        expect(text, isNot(contains(fragment)), reason: '$file: $fragment');
      }
    }
  });

  test('Android native parser keeps parity with Dart slot parsing rules', () {
    final parser =
        File(
          'android/app/src/main/kotlin/com/hainanu/hai_schedule/ScheduleNativeParser.kt',
        ).readAsStringSync();

    expect(parser, contains(r'(?:\\s*-\\s*(\\d+))?节'));
    expect(parser, contains('raw.split(Regex("[;；]"))'));
    expect(parser, contains(".replace('，', ',')"));
    expect(parser, contains(".replace('（', '(')"));
    expect(parser, contains(".replace('）', ')')"));
    expect(parser, contains('if (activeWeeks.isEmpty()) return null'));
    expect(parser, contains('if (week in 1..53'));
    expect(parser, contains('startSection < 1 ||'));
  });
}
