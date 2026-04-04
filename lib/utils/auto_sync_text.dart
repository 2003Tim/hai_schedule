import 'package:hai_schedule/models/auto_sync_models.dart';
import 'package:hai_schedule/utils/auto_sync_schedule_policy.dart';

class AutoSyncText {
  const AutoSyncText._();

  static String formatDateTime(DateTime? time) {
    if (time == null) return '--';
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  static String describeFrequency(AutoSyncFrequency frequency) {
    switch (frequency) {
      case AutoSyncFrequency.manual:
        return '仅手动同步';
      case AutoSyncFrequency.daily:
        return '每天自动同步';
      case AutoSyncFrequency.weekly:
        return '每周自动同步';
      case AutoSyncFrequency.monthly:
        return '每月自动同步';
      case AutoSyncFrequency.custom:
        return '自定义自动同步';
    }
  }

  static String describeSettings(AutoSyncSettings settings) {
    if (settings.frequency != AutoSyncFrequency.custom) {
      return describeFrequency(settings.frequency);
    }
    return '每${formatIntervalMinutes(settings.customIntervalMinutes)}自动同步';
  }

  static String formatIntervalMinutes(int minutes) {
    final normalized = AutoSyncSchedulePolicy.normalizeCustomIntervalMinutes(
      minutes,
    );
    if (normalized % (24 * 60) == 0) {
      return '${normalized ~/ (24 * 60)}天';
    }
    if (normalized % 60 == 0) {
      return '${normalized ~/ 60}小时';
    }
    return '$normalized分钟';
  }

  static String buildSuccessMessage(int courseCount, String? diffSummary) {
    final base = '已同步 $courseCount 门课程';
    if (diffSummary == null || diffSummary.isEmpty) {
      return base;
    }
    return '$base，$diffSummary';
  }

  static bool looksLikeLoginFailure(String message) {
    final lower = message.toLowerCase();
    return lower.contains('重新登录') ||
        lower.contains('登录态') ||
        lower.contains('cookie') ||
        lower.contains('code=') ||
        lower.contains('401') ||
        lower.contains('403');
  }
}
