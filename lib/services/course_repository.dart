import 'dart:convert';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_parser.dart';
import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/models/semester_option.dart';
import 'package:hai_schedule/models/undergraduate_schedule_parser.dart';
import 'package:hai_schedule/services/api_service.dart';
import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/services/portal_redirect_exception.dart';
import 'package:hai_schedule/services/semester_catalog_parser.dart';

typedef SemesterCatalogUpdateCallback =
    Future<void> Function(List<SemesterOption> options);

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

  Future<List<SemesterOption>> fetchSemesterCatalog({
    String? cookie,
    SemesterCatalogUpdateCallback? onCatalogUpdated,
  }) async {
    if (cookie != null && cookie.isNotEmpty) {
      updateCookie(cookie);
    }

    final page = await _apiService.fetchPortalHomePage();
    if (!_looksLikeHtmlPage(page)) {
      throw const PortalRedirectException();
    }

    final parsedOptions = SemesterCatalogParser.parseHtml(page.body);
    await _storage.saveSemesterCatalog(parsedOptions);
    final persistedCatalog = await _storage.loadSemesterCatalog();
    final isPersistedCatalogValid =
        persistedCatalog.length == parsedOptions.length &&
        parsedOptions.every(persistedCatalog.contains);
    if (!isPersistedCatalogValid) {
      throw StateError('学期目录保存后读取校验失败');
    }
    if (onCatalogUpdated != null) {
      await onCatalogUpdated(persistedCatalog);
    }
    return persistedCatalog;
  }

  Future<CourseFetchResult> syncCourse({
    required String semester,
    String? cookie,
    ScheduleSource source = ScheduleSource.graduate,
    SemesterCatalogUpdateCallback? onSemesterCatalogUpdated,
  }) async {
    if (cookie != null && cookie.isNotEmpty) {
      updateCookie(cookie);
    }

    if (source.isUndergraduate) {
      return fetchUndergraduateSchedule(
        semester: semester,
        onSemesterCatalogUpdated: onSemesterCatalogUpdated,
      );
    }

    // 每次同步都主动拉取最新的学期目录，确保 provider 回调被调用、
    // 内存与磁盘数据保持最新。不再依赖"catalog 为空"才抓取的条件判断，
    // 否则自动同步路径里 onSemesterCatalogUpdated 永远不会被执行。
    await fetchSemesterCatalog(onCatalogUpdated: onSemesterCatalogUpdated);

    return fetchGraduateSchedule(semester: semester);
  }

  Future<CourseFetchResult> fetchUndergraduateSchedule({
    required String semester,
    String? cookie,
    SemesterCatalogUpdateCallback? onSemesterCatalogUpdated,
  }) async {
    if (cookie != null && cookie.isNotEmpty) {
      updateCookie(cookie);
    }

    final page = await _apiService.fetchUndergraduateSchedulePage(
      semester: semester,
    );
    final parsed = UndergraduateScheduleParser.parseHtml(page.body);
    final courses = parsed.courses;
    if (courses.isEmpty) {
      throw ApiException('未解析到课程数据，请检查是否有选课');
    }

    if (parsed.semesterOptions.isNotEmpty) {
      await _storage.saveSemesterCatalog(parsed.semesterOptions);
    }
    // #C1: always notify the callback, even when no semester options were
    // parsed. The graduate branch already does this unconditionally
    // (syncCourse → fetchSemesterCatalog). Without this, after a successful
    // undergrad sync the in-memory ScheduleProvider.knownSemesterCatalog
    // can permanently lag behind disk.
    if (onSemesterCatalogUpdated != null) {
      await onSemesterCatalogUpdated(await _storage.loadSemesterCatalog());
    }

    return CourseFetchResult(
      rawData: <String, dynamic>{
        'source': ScheduleSource.undergraduate.value,
        'semester':
            parsed.semesterCode.isNotEmpty ? parsed.semesterCode : semester,
      },
      rawJson: page.body,
      courses: courses,
    );
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
