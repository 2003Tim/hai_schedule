enum ReminderLeadTimeOption {
  off(0, '关闭'),
  fiveMinutes(5, '提前 5 分钟'),
  tenMinutes(10, '提前 10 分钟'),
  fifteenMinutes(15, '提前 15 分钟'),
  thirtyMinutes(30, '提前 30 分钟');

  final int minutes;
  final String label;

  const ReminderLeadTimeOption(this.minutes, this.label);

  static ReminderLeadTimeOption fromMinutes(int? minutes) {
    return ReminderLeadTimeOption.values.firstWhere(
      (item) => item.minutes == minutes,
      orElse: () => ReminderLeadTimeOption.off,
    );
  }
}

class ReminderSettings {
  final ReminderLeadTimeOption leadTime;

  const ReminderSettings({required this.leadTime});

  bool get enabled => leadTime != ReminderLeadTimeOption.off;
}

class ReminderSnapshot {
  final ReminderSettings settings;
  final DateTime? lastBuildTime;
  final DateTime? horizonEnd;
  final int scheduledCount;
  final bool exactAlarmEnabled;

  const ReminderSnapshot({
    required this.settings,
    this.lastBuildTime,
    this.horizonEnd,
    this.scheduledCount = 0,
    this.exactAlarmEnabled = false,
  });
}

class ReminderApplyResult {
  final ReminderSnapshot snapshot;
  final String message;
  final int scheduledCount;
  final bool notificationsGranted;
  final bool exactAlarmEnabled;

  const ReminderApplyResult({
    required this.snapshot,
    required this.message,
    this.scheduledCount = 0,
    this.notificationsGranted = true,
    this.exactAlarmEnabled = false,
  });
}

class ReminderPreviewItem {
  final String courseName;
  final String location;
  final String timeRange;
  final String dateLabel;
  final DateTime remindAt;
  final int leadMinutes;

  const ReminderPreviewItem({
    required this.courseName,
    required this.location,
    required this.timeRange,
    required this.dateLabel,
    required this.remindAt,
    required this.leadMinutes,
  });
}
