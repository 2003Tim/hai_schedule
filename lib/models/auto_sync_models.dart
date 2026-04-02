enum AutoSyncFrequency {
  manual('manual', '仅手动'),
  daily('daily', '每天'),
  weekly('weekly', '每周'),
  monthly('monthly', '每月'),
  custom('custom', '自定义');

  final String value;
  final String label;

  const AutoSyncFrequency(this.value, this.label);

  static AutoSyncFrequency fromValue(String? value) {
    return AutoSyncFrequency.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AutoSyncFrequency.daily,
    );
  }
}

enum AutoSyncState {
  idle('idle'),
  syncing('syncing'),
  success('success'),
  failed('failed'),
  loginRequired('login_required');

  final String value;

  const AutoSyncState(this.value);

  static AutoSyncState fromValue(String? value) {
    return AutoSyncState.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AutoSyncState.idle,
    );
  }
}

class AutoSyncSettings {
  final AutoSyncFrequency frequency;
  final int customIntervalMinutes;

  const AutoSyncSettings({
    required this.frequency,
    required this.customIntervalMinutes,
  });

  bool get backgroundEnabled => frequency != AutoSyncFrequency.manual;

  Duration get interval {
    switch (frequency) {
      case AutoSyncFrequency.manual:
        return const Duration(days: 36500);
      case AutoSyncFrequency.daily:
        return const Duration(days: 1);
      case AutoSyncFrequency.weekly:
        return const Duration(days: 7);
      case AutoSyncFrequency.monthly:
        return const Duration(days: 30);
      case AutoSyncFrequency.custom:
        return Duration(minutes: customIntervalMinutes);
    }
  }
}

class AutoSyncSnapshot {
  final AutoSyncSettings settings;
  final AutoSyncState state;
  final String message;
  final DateTime? lastFetchTime;
  final DateTime? lastAttemptTime;
  final DateTime? nextSyncTime;
  final String? lastError;
  final String? lastSource;
  final String? lastDiffSummary;
  final bool credentialReady;

  const AutoSyncSnapshot({
    required this.settings,
    required this.state,
    required this.message,
    this.lastFetchTime,
    this.lastAttemptTime,
    this.nextSyncTime,
    this.lastError,
    this.lastSource,
    this.lastDiffSummary,
    this.credentialReady = false,
  });

  bool get requiresLogin => state == AutoSyncState.loginRequired;
}

class AutoSyncResult {
  final bool attempted;
  final bool didSync;
  final bool requiresLogin;
  final int? courseCount;
  final String message;
  final AutoSyncSnapshot snapshot;

  const AutoSyncResult({
    required this.attempted,
    required this.didSync,
    required this.requiresLogin,
    required this.message,
    required this.snapshot,
    this.courseCount,
  });

  factory AutoSyncResult.skipped(String message, AutoSyncSnapshot snapshot) {
    return AutoSyncResult(
      attempted: false,
      didSync: false,
      requiresLogin: false,
      message: message,
      snapshot: snapshot,
    );
  }

  factory AutoSyncResult.loginRequired(
    String message,
    AutoSyncSnapshot snapshot,
  ) {
    return AutoSyncResult(
      attempted: true,
      didSync: false,
      requiresLogin: true,
      message: message,
      snapshot: snapshot,
    );
  }

  factory AutoSyncResult.failed(String message, AutoSyncSnapshot snapshot) {
    return AutoSyncResult(
      attempted: true,
      didSync: false,
      requiresLogin: false,
      message: message,
      snapshot: snapshot,
    );
  }

  factory AutoSyncResult.success(
    int count,
    String message,
    AutoSyncSnapshot snapshot,
  ) {
    return AutoSyncResult(
      attempted: true,
      didSync: true,
      requiresLogin: false,
      message: message,
      snapshot: snapshot,
      courseCount: count,
    );
  }
}
