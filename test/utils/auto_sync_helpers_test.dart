import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/auto_sync_models.dart';
import 'package:hai_schedule/utils/auto_sync_schedule_policy.dart';
import 'package:hai_schedule/utils/auto_sync_text.dart';

void main() {
  group('AutoSyncSchedulePolicy', () {
    test('normalizes custom interval minutes within supported range', () {
      expect(
        AutoSyncSchedulePolicy.normalizeCustomIntervalMinutes(null),
        AutoSyncSchedulePolicy.defaultCustomIntervalMinutes,
      );
      expect(
        AutoSyncSchedulePolicy.normalizeCustomIntervalMinutes(30),
        AutoSyncSchedulePolicy.minCustomIntervalMinutes,
      );
      expect(
        AutoSyncSchedulePolicy.normalizeCustomIntervalMinutes(999999),
        AutoSyncSchedulePolicy.maxCustomIntervalMinutes,
      );
    });

    test('keeps today target time for daily sync before scheduled hour', () {
      const settings = AutoSyncSettings(
        frequency: AutoSyncFrequency.daily,
        customIntervalMinutes:
            AutoSyncSchedulePolicy.defaultCustomIntervalMinutes,
      );

      final nextTime = AutoSyncSchedulePolicy.computeNextSyncTime(
        settings: settings,
        now: DateTime(2026, 4, 2, 5, 45),
        afterSuccessfulSync: false,
        preserveExistingCustomSchedule: true,
      );

      expect(nextTime, DateTime(2026, 4, 2, 6, 30));
    });

    test('preserves custom future schedule before next successful sync', () {
      const settings = AutoSyncSettings(
        frequency: AutoSyncFrequency.custom,
        customIntervalMinutes: 180,
      );
      final now = DateTime(2026, 4, 2, 10, 0);
      final previousNextTime = DateTime(2026, 4, 2, 11, 30);

      final nextTime = AutoSyncSchedulePolicy.computeNextSyncTime(
        settings: settings,
        now: now,
        afterSuccessfulSync: false,
        preserveExistingCustomSchedule: true,
        previousNextSyncTime: previousNextTime,
      );

      expect(nextTime, previousNextTime);
    });
  });

  group('AutoSyncText', () {
    test('formats custom settings with normalized interval text', () {
      const settings = AutoSyncSettings(
        frequency: AutoSyncFrequency.custom,
        customIntervalMinutes: 120,
      );

      expect(AutoSyncText.describeSettings(settings), '每2小时自动同步');
    });

    test('detects common login failure signals', () {
      expect(AutoSyncText.looksLikeLoginFailure('请求失败 code=401'), isTrue);
      expect(AutoSyncText.looksLikeLoginFailure('接口超时，请稍后重试'), isFalse);
    });
  });
}
