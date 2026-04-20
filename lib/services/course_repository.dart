import 'dart:convert';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_parser.dart';
import 'package:hai_schedule/services/api_service.dart';

class CourseFetchResult {
  final Map<String, dynamic> rawData;
  final String rawJson;
  final List<Course> courses;

  const CourseFetchResult({
    required this.rawData,
    required this.rawJson,
    required this.courses,
  });
}

class CourseRepository {
  CourseRepository({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  String? get currentCookie => _apiService.currentCookie;

  void updateCookie(String cookie) {
    _apiService.updateCookie(cookie);
  }

  Future<CourseFetchResult> fetchGraduateSchedule({
    required String semester,
    String? cookie,
  }) async {
    if (cookie != null && cookie.isNotEmpty) {
      updateCookie(cookie);
    }

    final rawData = await _apiService.fetchGraduateScheduleRaw(
      semester: semester,
    );
    final courses = ScheduleParser.parseApiResponse(rawData);
    if (courses.isEmpty) {
      throw ApiException('未解析到课程数据，请检查是否有选课');
    }

    return CourseFetchResult(
      rawData: rawData,
      rawJson: jsonEncode(rawData),
      courses: courses,
    );
  }
}
