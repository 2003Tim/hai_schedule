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

  factory ScheduleOverride.fromJson(Map<String, dynamic> json) => ScheduleOverride(
        id: json['id'] as String? ?? '',
        semesterCode: json['semesterCode'] as String? ?? '',
        dateKey: json['dateKey'] as String? ?? '',
        weekday: json['weekday'] as int? ?? 1,
        startSection: json['startSection'] as int? ?? 1,
        endSection: json['endSection'] as int? ?? 1,
        type: ScheduleOverrideType.values.byName(json['type'] as String? ?? 'add'),
        targetCourseId: json['targetCourseId'] as String?,
        courseName: json['courseName'] as String? ?? '',
        teacher: json['teacher'] as String? ?? '',
        location: json['location'] as String? ?? '',
        note: json['note'] as String? ?? '',
        status: ScheduleOverrideStatus.values.byName(
          json['status'] as String? ?? 'normal',
        ),
        sourceCourseName: json['sourceCourseName'] as String? ?? '',
        sourceTeacher: json['sourceTeacher'] as String? ?? '',
        sourceLocation: json['sourceLocation'] as String? ?? '',
        sourceStartSection: json['sourceStartSection'] as int?,
        sourceEndSection: json['sourceEndSection'] as int?,
      );
}

enum ScheduleOverrideType {
  add,
  cancel,
  modify,
}

enum ScheduleOverrideStatus {
  normal,
  orphaned,
}
