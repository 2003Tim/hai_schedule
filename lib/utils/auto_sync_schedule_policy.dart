import 'package:hai_schedule/models/auto_sync_models.dart';

class AutoSyncSchedulePolicy {
  const AutoSyncSchedulePolicy._();

  static const Duration retryBackoff = Duration(minutes: 30);
  static const int defaultCustomIntervalMinutes = 12 * 60;
  static const int minCustomIntervalMinutes = 60;
  static const int maxCustomIntervalMinutes = 30 * 24 * 60;

  static int normalizeCustomIntervalMinutes(int? minutes) {
    final value = minutes ?? defaultCustomIntervalMinutes;
    if (value < minCustomIntervalMinutes) {
      return minCustomIntervalMinutes;
    }
    if (value > maxCustomIntervalMinutes) {
      return maxCustomIntervalMinutes;
    }
    return value;
  }

  static DateTime? computeNextSyncTime({
    required AutoSyncSettings settings,
    required DateTime now,
    required bool afterSuccessfulSync,
    required bool preserveExistingCustomSchedule,
    DateTime? previousNextSyncTime,
    DateTime? lastFetchTime,
    DateTime? lastAttemptTime,
  }) {
    if (!settings.backgroundEnabled) {
      return null;
    }

    if (settings.frequency == AutoSyncFrequency.custom) {
      final interval = settings.interval;
      if (!afterSuccessfulSync && preserveExistingCustomSchedule) {
        if (previousNextSyncTime != null && previousNextSyncTime.isAfter(now)) {
          return previousNextSyncTime;
        }

        DateTime? anchor;
        if (lastFetchTime != null) {
          anchor = lastFetchTime;
        }
        if (lastAttemptTime != null &&
            (anchor == null || lastAttemptTime.isAfter(anchor))) {
          anchor = lastAttemptTime;
        }
        if (anchor != null) {
          final anchoredNextTime = anchor.add(interval);
          if (anchoredNextTime.isAfter(now)) {
            return anchoredNextTime;
          }
        }
      }
      return now.add(interval);
    }

    switch (settings.frequency) {
      case AutoSyncFrequency.manual:
        return null;
      case AutoSyncFrequency.daily:
        final todayAtTarget = DateTime(now.year, now.month, now.day, 6, 30);
        if (afterSuccessfulSync || !todayAtTarget.isAfter(now)) {
          return todayAtTarget.add(const Duration(days: 1));
        }
        return todayAtTarget;
      case AutoSyncFrequency.weekly:
        var target = DateTime(now.year, now.month, now.day, 6, 30);
        while (target.weekday != DateTime.monday) {
          target = target.add(const Duration(days: 1));
        }
        if (afterSuccessfulSync || !target.isAfter(now)) {
          target = target.add(const Duration(days: 7));
        }
        return target;
      case AutoSyncFrequency.monthly:
        var target = DateTime(now.year, now.month, 1, 6, 30);
        if (afterSuccessfulSync || !target.isAfter(now)) {
          target = DateTime(now.year, now.month + 1, 1, 6, 30);
        }
        return target;
      case AutoSyncFrequency.custom:
        return null;
    }
  }
}
