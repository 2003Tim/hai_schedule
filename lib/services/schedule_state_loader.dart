import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_override.dart';
import 'package:hai_schedule/models/schedule_parser.dart';
import 'package:hai_schedule/models/school_time.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/utils/week_calculator.dart';

class LoadedScheduleState {
  final List<Course> courses;
  final List<ScheduleOverride> overrides;
  final SchoolTimeConfig timeConfig;
  final String? currentSemesterCode;
  final List<String> availableSemesterCodes;
  final int displayDays;
  final bool showNonCurrentWeek;

  const LoadedScheduleState({
    required this.courses,
    required this.overrides,
    required this.timeConfig,
    required this.currentSemesterCode,
    required this.availableSemesterCodes,
    required this.displayDays,
    required this.showNonCurrentWeek,
  });
}

class ScheduleStateLoader {
  ScheduleStateLoader({
    ScheduleRepository? scheduleRepository,
    SchedulePreferencesRepository? preferencesRepository,
    ScheduleOverrideRepository? overrideRepository,
    SchoolTimeRepository? schoolTimeRepository,
  }) : _scheduleRepository = scheduleRepository ?? ScheduleRepository(),
       _preferencesRepository =
           preferencesRepository ?? SchedulePreferencesRepository(),
       _overrideRepository = overrideRepository ?? ScheduleOverrideRepository(),
       _schoolTimeRepository = schoolTimeRepository ?? SchoolTimeRepository();

  final ScheduleRepository _scheduleRepository;
  final SchedulePreferencesRepository _preferencesRepository;
  final ScheduleOverrideRepository _overrideRepository;
  final SchoolTimeRepository _schoolTimeRepository;

  Future<LoadedScheduleState> load() async {
    final activeSemester = await _scheduleRepository.loadActiveSemesterCode();
    final cache = await _scheduleRepository.loadCache(
      semesterCode: activeSemester,
    );
    final preferences = await _preferencesRepository.load();

    return LoadedScheduleState(
      courses: await _resolveCourses(cache),
      overrides: await _overrideRepository.load(cache.semesterCode),
      timeConfig: await _schoolTimeRepository.load(),
      currentSemesterCode: cache.semesterCode,
      availableSemesterCodes: await loadAvailableSemesterCodes(
        additional: cache.semesterCode,
      ),
      displayDays: preferences.displayDays,
      showNonCurrentWeek: preferences.showNonCurrentWeek,
    );
  }

  Future<List<String>> loadAvailableSemesterCodes({String? additional}) async {
    final available = await _scheduleRepository.loadAvailableSemesterCodes();
    final merged = <String>{...available};
    if (additional != null && additional.isNotEmpty) {
      merged.add(additional);
    }
    return merged.toList()..sort((a, b) => b.compareTo(a));
  }

  Future<String> resolveTargetSemesterCode(String? semesterCode) async {
    if (semesterCode != null && semesterCode.isNotEmpty) {
      return semesterCode;
    }
    final activeSemester = await _scheduleRepository.loadActiveSemesterCode();
    if (activeSemester != null && activeSemester.isNotEmpty) {
      return activeSemester;
    }
    return inferSemesterCode(DateTime.now());
  }

  String inferSemesterCode(DateTime now) {
    return WeekCalculator.inferSemesterCode(now);
  }

  Future<List<Course>> _resolveCourses(ScheduleCache cache) async {
    if (cache.rawScheduleJson != null && cache.rawScheduleJson!.isNotEmpty) {
      try {
        final data = json.decode(cache.rawScheduleJson!) as Map<String, dynamic>;
        final parsedCourses = ScheduleParser.parseApiResponse(data);
        if (parsedCourses.isNotEmpty) {
          await _scheduleRepository.saveSemesterSchedule(
            semesterCode:
                cache.semesterCode ?? await resolveTargetSemesterCode(null),
            rawScheduleJson: cache.rawScheduleJson,
            courses: parsedCourses,
            makeActive: true,
          );
          return parsedCourses;
        }
      } catch (error) {
        debugPrint('从原始课表缓存恢复失败: $error');
      }
    }

    if (cache.courses.isNotEmpty) {
      return cache.courses;
    }

    final storedCourses = await _scheduleRepository.loadCourses();
    if (storedCourses.isNotEmpty) {
      return storedCourses;
    }

    return const <Course>[];
  }
}
