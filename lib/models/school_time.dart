class SchoolTimeConfig {
  final String name;
  final List<ClassTime> classTimes;

  SchoolTimeConfig({required this.name, required this.classTimes});

  ClassTime? getClassTime(int section) {
    if (section < 1 || section > classTimes.length) return null;
    return classTimes[section - 1];
  }

  (String startTime, String endTime)? getSlotTime(
    int startSection,
    int endSection,
  ) {
    final start = getClassTime(startSection);
    final end = getClassTime(endSection);
    if (start == null || end == null) return null;
    return (start.startTime, end.endTime);
  }

  int get totalSections => classTimes.length;

  SchoolTimeConfig copyWith({String? name, List<ClassTime>? classTimes}) {
    return SchoolTimeConfig(
      name: name ?? this.name,
      classTimes: classTimes ?? this.classTimes,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'classTimes': classTimes.map((c) => c.toJson()).toList(),
  };

  factory SchoolTimeConfig.fromJson(Map<String, dynamic> json) {
    final rawClassTimes = json['classTimes'] as List? ?? const [];
    return SchoolTimeConfig(
      name: json['name']?.toString() ?? '自定义作息',
      classTimes:
          rawClassTimes
              .map(
                (c) => ClassTime.fromJson(Map<String, dynamic>.from(c as Map)),
              )
              .toList(),
    );
  }

  factory SchoolTimeConfig.hainanuDefault() => SchoolTimeConfig(
    name: '海南大学',
    classTimes: [
      ClassTime(section: 1, startTime: '07:40', endTime: '08:25'),
      ClassTime(section: 2, startTime: '08:35', endTime: '09:20'),
      ClassTime(section: 3, startTime: '09:45', endTime: '10:30'),
      ClassTime(section: 4, startTime: '10:40', endTime: '11:25'),
      ClassTime(section: 5, startTime: '14:30', endTime: '15:15'),
      ClassTime(section: 6, startTime: '15:25', endTime: '16:10'),
      ClassTime(section: 7, startTime: '16:35', endTime: '17:20'),
      ClassTime(section: 8, startTime: '17:30', endTime: '18:15'),
      ClassTime(section: 9, startTime: '19:20', endTime: '20:05'),
      ClassTime(section: 10, startTime: '20:15', endTime: '21:00'),
      ClassTime(section: 11, startTime: '21:10', endTime: '21:55'),
    ],
  );
}

class ClassTime {
  final int section;
  final String startTime;
  final String endTime;

  ClassTime({
    required this.section,
    required this.startTime,
    required this.endTime,
  });

  int get startMinutes => _timeToMinutes(startTime);
  int get endMinutes => _timeToMinutes(endTime);

  ClassTime copyWith({int? section, String? startTime, String? endTime}) {
    return ClassTime(
      section: section ?? this.section,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }

  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Map<String, dynamic> toJson() => {
    'section': section,
    'startTime': startTime,
    'endTime': endTime,
  };

  factory ClassTime.fromJson(Map<String, dynamic> json) => ClassTime(
    section: json['section'] as int,
    startTime: json['startTime'] as String,
    endTime: json['endTime'] as String,
  );

  @override
  String toString() => '第$section节 $startTime~$endTime';
}

class SchoolTimeGeneratorSettings {
  final int morningCount;
  final int afternoonCount;
  final int eveningCount;
  final int lessonMinutes;
  final int breakMinutes;
  final int morningLongBreakMinutes;
  final int afternoonLongBreakMinutes;
  final int morningLongBreakAfter;
  final int afternoonLongBreakAfter;
  final String morningStart;
  final String afternoonStart;
  final String eveningStart;
  final bool enableMorningLongBreak;
  final bool enableAfternoonLongBreak;

  const SchoolTimeGeneratorSettings({
    required this.morningCount,
    required this.afternoonCount,
    required this.eveningCount,
    required this.lessonMinutes,
    required this.breakMinutes,
    required this.morningLongBreakMinutes,
    required this.afternoonLongBreakMinutes,
    required this.morningLongBreakAfter,
    required this.afternoonLongBreakAfter,
    required this.morningStart,
    required this.afternoonStart,
    required this.eveningStart,
    required this.enableMorningLongBreak,
    required this.enableAfternoonLongBreak,
  });

  factory SchoolTimeGeneratorSettings.defaults() =>
      const SchoolTimeGeneratorSettings(
        morningCount: 4,
        afternoonCount: 4,
        eveningCount: 3,
        lessonMinutes: 45,
        breakMinutes: 10,
        morningLongBreakMinutes: 25,
        afternoonLongBreakMinutes: 25,
        morningLongBreakAfter: 2,
        afternoonLongBreakAfter: 2,
        morningStart: '07:40',
        afternoonStart: '14:30',
        eveningStart: '19:20',
        enableMorningLongBreak: true,
        enableAfternoonLongBreak: true,
      );

  Map<String, dynamic> toJson() => {
    'morningCount': morningCount,
    'afternoonCount': afternoonCount,
    'eveningCount': eveningCount,
    'lessonMinutes': lessonMinutes,
    'breakMinutes': breakMinutes,
    'morningLongBreakMinutes': morningLongBreakMinutes,
    'afternoonLongBreakMinutes': afternoonLongBreakMinutes,
    'morningLongBreakAfter': morningLongBreakAfter,
    'afternoonLongBreakAfter': afternoonLongBreakAfter,
    'morningStart': morningStart,
    'afternoonStart': afternoonStart,
    'eveningStart': eveningStart,
    'enableMorningLongBreak': enableMorningLongBreak,
    'enableAfternoonLongBreak': enableAfternoonLongBreak,
  };

  factory SchoolTimeGeneratorSettings.fromJson(Map<String, dynamic> json) {
    final defaults = SchoolTimeGeneratorSettings.defaults();
    return SchoolTimeGeneratorSettings(
      morningCount: json['morningCount'] as int? ?? defaults.morningCount,
      afternoonCount: json['afternoonCount'] as int? ?? defaults.afternoonCount,
      eveningCount: json['eveningCount'] as int? ?? defaults.eveningCount,
      lessonMinutes: json['lessonMinutes'] as int? ?? defaults.lessonMinutes,
      breakMinutes: json['breakMinutes'] as int? ?? defaults.breakMinutes,
      morningLongBreakMinutes:
          json['morningLongBreakMinutes'] as int? ??
          defaults.morningLongBreakMinutes,
      afternoonLongBreakMinutes:
          json['afternoonLongBreakMinutes'] as int? ??
          defaults.afternoonLongBreakMinutes,
      morningLongBreakAfter:
          json['morningLongBreakAfter'] as int? ??
          defaults.morningLongBreakAfter,
      afternoonLongBreakAfter:
          json['afternoonLongBreakAfter'] as int? ??
          defaults.afternoonLongBreakAfter,
      morningStart: json['morningStart'] as String? ?? defaults.morningStart,
      afternoonStart:
          json['afternoonStart'] as String? ?? defaults.afternoonStart,
      eveningStart: json['eveningStart'] as String? ?? defaults.eveningStart,
      enableMorningLongBreak:
          json['enableMorningLongBreak'] as bool? ??
          defaults.enableMorningLongBreak,
      enableAfternoonLongBreak:
          json['enableAfternoonLongBreak'] as bool? ??
          defaults.enableAfternoonLongBreak,
    );
  }
}
