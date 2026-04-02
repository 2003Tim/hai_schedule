class ClassSilenceSettings {
  final bool enabled;

  const ClassSilenceSettings({required this.enabled});
}

class ClassSilenceSnapshot {
  final ClassSilenceSettings settings;
  final bool supported;
  final bool policyAccessGranted;
  final DateTime? lastBuildTime;
  final DateTime? horizonEnd;
  final int scheduledCount;

  const ClassSilenceSnapshot({
    required this.settings,
    required this.supported,
    required this.policyAccessGranted,
    this.lastBuildTime,
    this.horizonEnd,
    this.scheduledCount = 0,
  });
}

class ClassSilenceApplyResult {
  final ClassSilenceSnapshot snapshot;
  final String message;
  final bool policyAccessGranted;

  const ClassSilenceApplyResult({
    required this.snapshot,
    required this.message,
    required this.policyAccessGranted,
  });
}

class SilenceScheduleEvent {
  final String id;
  final String courseName;
  final String date;
  final int startSection;
  final int endSection;
  final int startAtMillis;
  final int endAtMillis;

  const SilenceScheduleEvent({
    required this.id,
    required this.courseName,
    required this.date,
    required this.startSection,
    required this.endSection,
    required this.startAtMillis,
    required this.endAtMillis,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseName': courseName,
    'date': date,
    'startSection': startSection,
    'endSection': endSection,
    'startAtMillis': startAtMillis,
    'endAtMillis': endAtMillis,
  };
}
