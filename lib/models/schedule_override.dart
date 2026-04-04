class ScheduleOverride {
  final String id;
  final String semesterCode;
  final String dateKey;
  final int weekday;
  final int startSection;
  final int endSection;
  final ScheduleOverrideType type;
  final String? targetCourseId;
  final String courseName;
  final String teacher;
  final String location;
  final String note;
  final ScheduleOverrideStatus status;
  final String sourceCourseName;
  final String sourceTeacher;
  final String sourceLocation;
  final int? sourceStartSection;
  final int? sourceEndSection;

  const ScheduleOverride({
    required this.id,
    required this.semesterCode,
    required this.dateKey,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.type,
    this.targetCourseId,
    this.courseName = '',
    this.teacher = '',
    this.location = '',
    this.note = '',
    this.status = ScheduleOverrideStatus.normal,
    this.sourceCourseName = '',
    this.sourceTeacher = '',
    this.sourceLocation = '',
    this.sourceStartSection,
    this.sourceEndSection,
  });

  int get sectionSpan => endSection - startSection + 1;

  bool coversSection(int section) {
    return startSection <= section && endSection >= section;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'semesterCode': semesterCode,
    'dateKey': dateKey,
    'weekday': weekday,
    'startSection': startSection,
    'endSection': endSection,
    'type': type.name,
    'targetCourseId': targetCourseId,
    'courseName': courseName,
    'teacher': teacher,
    'location': location,
    'note': note,
    'status': status.name,
    'sourceCourseName': sourceCourseName,
    'sourceTeacher': sourceTeacher,
    'sourceLocation': sourceLocation,
    'sourceStartSection': sourceStartSection,
    'sourceEndSection': sourceEndSection,
  };

  factory ScheduleOverride.fromJson(Map<String, dynamic> json) =>
      ScheduleOverride(
        id: _stringValue(json['id']),
        semesterCode: _stringValue(json['semesterCode']),
        dateKey: _stringValue(json['dateKey']),
        weekday: _intValue(json['weekday'], fallback: 1),
        startSection: _intValue(json['startSection'], fallback: 1),
        endSection: _intValue(json['endSection'], fallback: 1),
        type: _overrideTypeValue(json['type']),
        targetCourseId: json['targetCourseId']?.toString(),
        courseName: _stringValue(json['courseName']),
        teacher: _stringValue(json['teacher']),
        location: _stringValue(json['location']),
        note: _stringValue(json['note']),
        status: _overrideStatusValue(json['status']),
        sourceCourseName: _stringValue(json['sourceCourseName']),
        sourceTeacher: _stringValue(json['sourceTeacher']),
        sourceLocation: _stringValue(json['sourceLocation']),
        sourceStartSection: _nullableInt(json['sourceStartSection']),
        sourceEndSection: _nullableInt(json['sourceEndSection']),
      );
}

enum ScheduleOverrideType { add, cancel, modify }

enum ScheduleOverrideStatus { normal, orphaned }

String _stringValue(Object? value) => value?.toString() ?? '';

int _intValue(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _nullableInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

ScheduleOverrideType _overrideTypeValue(Object? value) {
  final raw = value?.toString() ?? '';
  return ScheduleOverrideType.values.firstWhere(
    (item) => item.name == raw,
    orElse: () => ScheduleOverrideType.add,
  );
}

ScheduleOverrideStatus _overrideStatusValue(Object? value) {
  final raw = value?.toString() ?? '';
  return ScheduleOverrideStatus.values.firstWhere(
    (item) => item.name == raw,
    orElse: () => ScheduleOverrideStatus.normal,
  );
}
