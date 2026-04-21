import 'dart:convert';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/models/storage_records.dart';
import 'package:hai_schedule/utils/app_logger.dart';

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

    final courses = <Course>[];
    for (final raw in jsonList) {
      try {
        final decoded = json.decode(raw);
        if (decoded is! Map) continue;
        courses.add(Course.fromJson(Map<String, dynamic>.from(decoded)));
      } catch (error) {
        AppLogger.warn('AppStorage', '忽略损坏的课程镜像记录', error);
      }
    }
    return courses;
  }

  static Map<String, dynamic> decodeScheduleArchiveMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return <String, dynamic>{};
      }
      return Map<String, dynamic>.from(decoded);
    } catch (error) {
      AppLogger.warn('AppStorage', '课表归档 JSON 解析失败，已回退为空归档', error);
      return <String, dynamic>{};
    }
  }

  static String encodeScheduleArchiveMap(Map<String, dynamic> archive) {
    return json.encode(archive);
  }

  static Map<String, SemesterSyncRecord> decodeSemesterSyncRecordMap(
    String? raw,
  ) {
    if (raw == null || raw.isEmpty) {
      return <String, SemesterSyncRecord>{};
    }

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return <String, SemesterSyncRecord>{};
      }

      final records = <String, SemesterSyncRecord>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value;
        if (key.isEmpty || value is! Map) {
          continue;
        }
        try {
          records[key] = SemesterSyncRecord.fromJson(
            Map<String, dynamic>.from(value),
          );
        } catch (error) {
          AppLogger.warn('AppStorage', '忽略损坏的学期同步记录', error);
        }
      }
      return records;
    } catch (error) {
      AppLogger.warn('AppStorage', '学期同步记录解析失败，已回退为空映射', error);
      return <String, SemesterSyncRecord>{};
    }
  }

  static String encodeSemesterSyncRecordMap(
    Map<String, SemesterSyncRecord> records,
  ) {
    return json.encode(
      records.map((key, value) => MapEntry(key, value.toJson())),
    );
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
    final courses = <Course>[];
    for (final item in coursesJson) {
      if (item is! Map) continue;
      try {
        courses.add(Course.fromJson(Map<String, dynamic>.from(item)));
      } catch (error) {
        AppLogger.warn('AppStorage', '忽略损坏的归档课程记录', error);
      }
    }
    return courses;
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

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) {
        return const <ScheduleOverride>[];
      }

      final overrides = <ScheduleOverride>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          overrides.add(
            ScheduleOverride.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (error) {
          AppLogger.warn('AppStorage', '忽略损坏的临时调课记录', error);
        }
      }
      return overrides;
    } catch (error) {
      AppLogger.warn('AppStorage', '临时调课 JSON 解析失败，已回退为空列表', error);
      return const <ScheduleOverride>[];
    }
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
