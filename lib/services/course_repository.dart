import 'dart:convert';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_parser.dart';
import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/services/api_service.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/portal_redirect_exception.dart';
import 'package:hai_schedule/services/semester_catalog_parser.dart';

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
  CourseRepository({ApiService? apiService, AppStorage? storage})
    : _apiService = apiService ?? ApiService(),
      _storage = storage ?? AppStorage.instance;

  final ApiService _apiService;
  final AppStorage _storage;

  String? get currentCookie => _apiService.currentCookie;

  void updateCookie(String cookie) {
    _apiService.updateCookie(cookie);
  }

  Future<List<SemesterOption>> fetchSemesterCatalog({String? cookie}) async {
    if (cookie != null && cookie.isNotEmpty) {
      updateCookie(cookie);
    }

    final page = await _apiService.fetchPortalHomePage();
    if (!_looksLikeHtmlPage(page)) {
      throw const PortalRedirectException();
    }

    final options = SemesterCatalogParser.parseHtml(page.body);
    await _storage.saveKnownSemesterOptions(options);
    return options;
  }

  Future<CourseFetchResult> syncCourse({
    required String semester,
    String? cookie,
  }) async {
    if (cookie != null && cookie.isNotEmpty) {
      updateCookie(cookie);
    }

    final semesterCatalog = await _storage.loadKnownSemesterOptions();
    if (semesterCatalog.isEmpty) {
      await fetchSemesterCatalog();
    }

    return fetchGraduateSchedule(semester: semester);
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

  bool _looksLikeHtmlPage(PortalPageResult page) {
    final contentType = page.contentType?.toLowerCase() ?? '';
    if (contentType.startsWith('image/')) {
      return false;
    }
    if (contentType.isNotEmpty &&
        !contentType.contains('html') &&
        !contentType.contains('xml') &&
        !contentType.contains('text/plain')) {
      return false;
    }

    final body = page.body.trimLeft();
    if (body.isEmpty) {
      return false;
    }

    final lower = body.toLowerCase();
    return lower.startsWith('<!doctype html') ||
        lower.startsWith('<html') ||
        lower.contains('<body') ||
        lower.contains('<select') ||
        lower.contains('<form');
  }
}
