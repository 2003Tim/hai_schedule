import 'dart:convert';

import '../models/course.dart';
import '../models/schedule_override.dart';
import '../models/school_time.dart';
import '../models/storage_records.dart';
import 'app_logger.dart';

class AppStorageCodec {
  const AppStorageCodec._();

  static DateTime? readTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static List<Course> decodeGlobalCourseMirror(List<String>? jsonList) {
    if (jsonList == null || jsonList.isEmpty) {
      return const <Course>[];
    }

    return jsonList.map((raw) {
      final data = json.decode(raw) as Map<String, dynamic>;
      return Course.fromJson(data);
    }).toList();
  }

  static Map<String, dynamic> decodeScheduleArchiveMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = json.decode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, dynamic>{};
    }
    return Map<String, dynamic>.from(decoded);
  }

  static String encodeScheduleArchiveMap(Map<String, dynamic> archive) {
    return json.encode(archive);
  }

  static StoredSemesterSchedule? readSemesterArchive(
    Map<String, dynamic> archive,
    String semesterCode,
  ) {
    final raw = archive[semesterCode];
    if (raw is! Map<String, dynamic>) {
      return null;
    }

    return StoredSemesterSchedule(
      courses: decodeArchiveCourses(raw['courses']),
      rawScheduleJson: raw['rawScheduleJson'] as String?,
      semesterCode: semesterCode,
    );
  }

  static List<Course> decodeArchiveCourses(dynamic coursesJson) {
    if (coursesJson is! List) {
      return const <Course>[];
    }
    return coursesJson
        .whereType<Map>()
        .map((item) => Course.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static List<String>? encodeMirroredCourses(Map<String, dynamic>? entry) {
    final rawCourses = entry?['courses'] as List?;
    if (rawCourses == null) {
      return null;
    }

    return rawCourses
        .whereType<Map>()
        .map((item) => json.encode(Map<String, dynamic>.from(item)))
        .toList();
  }

  static List<ScheduleOverride> decodeScheduleOverrides(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const <ScheduleOverride>[];
    }

    final decoded = json.decode(raw);
    if (decoded is! List) {
      return const <ScheduleOverride>[];
    }

    return decoded
        .whereType<Map>()
        .map(
          (item) => ScheduleOverride.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  static String encodeScheduleOverrides(Iterable<ScheduleOverride> overrides) {
    return json.encode(overrides.map((item) => item.toJson()).toList());
  }

  static SchoolTimeConfig decodeSchoolTimeConfig(String? raw) {
    if (raw == null || raw.isEmpty) {
      return SchoolTimeConfig.hainanuDefault();
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return SchoolTimeConfig.hainanuDefault();
      }
      final config = SchoolTimeConfig.fromJson(decoded);
      if (config.classTimes.isEmpty) {
        return SchoolTimeConfig.hainanuDefault();
      }
      return config;
    } catch (error) {
      AppLogger.warn('AppStorage', '读取课程时间配置失败，使用默认值', error);
      return SchoolTimeConfig.hainanuDefault();
    }
  }

  static SchoolTimeGeneratorSettings decodeSchoolTimeGeneratorSettings(
    String? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return SchoolTimeGeneratorSettings.defaults();
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        return SchoolTimeGeneratorSettings.defaults();
      }
      return SchoolTimeGeneratorSettings.fromJson(decoded);
    } catch (error) {
      AppLogger.warn('AppStorage', '读取课程时间生成器设置失败，使用默认值', error);
      return SchoolTimeGeneratorSettings.defaults();
    }
  }
}
