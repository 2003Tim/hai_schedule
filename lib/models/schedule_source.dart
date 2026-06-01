enum ScheduleSource {
  graduate('graduate', '研究生'),
  undergraduate('undergraduate', '本科');

  const ScheduleSource(this.value, this.label);

  final String value;
  final String label;

  bool get isGraduate => this == ScheduleSource.graduate;
  bool get isUndergraduate => this == ScheduleSource.undergraduate;

  static ScheduleSource fromValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    for (final source in ScheduleSource.values) {
      if (source.value == normalized) return source;
    }
    return ScheduleSource.graduate;
  }
}
