/// 课程数据模型
class Course {
  final String id;
  final String code;
  final String name;
  final String className;
  final String teacher;
  final String college;
  final double credits;
  final int totalHours;
  final String semester;
  final String campus;
  final String teachingType;
  final List<ScheduleSlot> slots;

  Course({
    required this.id,
    required this.code,
    required this.name,
    required this.className,
    required this.teacher,
    required this.college,
    required this.credits,
    required this.totalHours,
    required this.semester,
    this.campus = '',
    this.teachingType = '',
    required this.slots,
  });

  /// 获取当前周某天的课程时段
  List<ScheduleSlot> getTodaySlots(int currentWeek, int weekday) {
    return slots.where((slot) {
        return slot.weekday == weekday && slot.isActiveInWeek(currentWeek);
      }).toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'name': name,
    'className': className,
    'teacher': teacher,
    'college': college,
    'credits': credits,
    'totalHours': totalHours,
    'semester': semester,
    'campus': campus,
    'teachingType': teachingType,
    'slots': slots.map((s) => s.toJson()).toList(),
  };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: _stringValue(json['id']),
    code: _stringValue(json['code']),
    name: _stringValue(json['name']),
    className: _stringValue(json['className']),
    teacher: _stringValue(json['teacher']),
    college: _stringValue(json['college']),
    credits: _doubleValue(json['credits']),
    totalHours: _intValue(json['totalHours']),
    semester: _stringValue(json['semester']),
    campus: _stringValue(json['campus']),
    teachingType: _stringValue(json['teachingType']),
    slots:
        (json['slots'] as List?)
            ?.whereType<Map>()
            .map((s) => ScheduleSlot.fromJson(Map<String, dynamic>.from(s)))
            .toList() ??
        [],
  );

  @override
  String toString() => 'Course($name, $teacher, ${slots.length} slots)';
}

/// 单个上课时段
class ScheduleSlot {
  final String courseId;
  final String courseName;
  final String teacher;
  final int weekday; // 1-7
  final int startSection;
  final int endSection;
  final String location;
  final List<WeekRange> weekRanges;

  ScheduleSlot({
    required this.courseId,
    required this.courseName,
    this.teacher = '',
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.location,
    required this.weekRanges,
  });

  /// 这个时段占几节课
  int get sectionSpan => endSection - startSection + 1;

  /// 判断某一周是否有课
  bool isActiveInWeek(int week) {
    return weekRanges.any((range) => range.containsWeek(week));
  }

  /// 获取所有有课的周次
  List<int> getAllActiveWeeks() {
    final weeks = <int>{};
    for (final range in weekRanges) {
      weeks.addAll(range.expandWeeks());
    }
    return weeks.toList()..sort();
  }

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'courseName': courseName,
    'teacher': teacher,
    'weekday': weekday,
    'startSection': startSection,
    'endSection': endSection,
    'location': location,
    'weekRanges': weekRanges.map((w) => w.toJson()).toList(),
  };

  factory ScheduleSlot.fromJson(Map<String, dynamic> json) => ScheduleSlot(
    courseId: _stringValue(json['courseId']),
    courseName: _stringValue(json['courseName']),
    teacher: _stringValue(json['teacher']),
    weekday: _intValue(json['weekday'], fallback: 1),
    startSection: _intValue(json['startSection'], fallback: 1),
    endSection: _intValue(json['endSection'], fallback: 1),
    location: _stringValue(json['location']),
    weekRanges:
        (json['weekRanges'] as List?)
            ?.whereType<Map>()
            .map((w) => WeekRange.fromJson(Map<String, dynamic>.from(w)))
            .toList() ??
        [],
  );

  @override
  String toString() =>
      'Slot(周${weekRanges.join(",")} 星期$weekday 第$startSection-$endSection节 $location)';
}

/// 周次范围
class WeekRange {
  final int start;
  final int end;
  final WeekType type;

  WeekRange({required this.start, required this.end, this.type = WeekType.all});

  bool containsWeek(int week) {
    if (week < start || week > end) return false;
    switch (type) {
      case WeekType.all:
        return true;
      case WeekType.odd:
        return week.isOdd;
      case WeekType.even:
        return week.isEven;
    }
  }

  List<int> expandWeeks() {
    final weeks = <int>[];
    for (int w = start; w <= end; w++) {
      if (containsWeek(w)) weeks.add(w);
    }
    return weeks;
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'type': type.name,
  };

  factory WeekRange.fromJson(Map<String, dynamic> json) => WeekRange(
    start: _intValue(json['start'], fallback: 1),
    end: _intValue(json['end'], fallback: 1),
    type: _weekTypeValue(json['type']),
  );

  @override
  String toString() {
    final suffix =
        type == WeekType.odd
            ? '单'
            : type == WeekType.even
            ? '双'
            : '';
    return '$start-$end$suffix周';
  }
}

enum WeekType { all, odd, even }

String _stringValue(Object? value) => value?.toString() ?? '';

int _intValue(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _doubleValue(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

WeekType _weekTypeValue(Object? value) {
  final raw = value?.toString() ?? '';
  return WeekType.values.firstWhere(
    (item) => item.name == raw,
    orElse: () => WeekType.all,
  );
}
