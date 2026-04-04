import 'package:dio/dio.dart';

import 'package:hai_schedule/models/course.dart';
import 'package:hai_schedule/models/schedule_parser.dart';

/// 教务系统 API 服务
class ApiService {
  static const _baseUrl = 'https://ehall.hainanu.edu.cn';
  static const _indexUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do';
  static const _graduateSchedulePath =
      '/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';
  static const _pageSize = 100;
  static const _maxPages = 20;

  final Dio _dio;

  ApiService({String? cookie})
    : _dio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Origin': _baseUrl,
            'Referer': _indexUrl,
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
            'Accept-Language': 'zh-CN,zh;q=0.9',
            if (cookie != null) 'Cookie': cookie,
          },
        ),
      );

  /// 更新 Cookie
  void updateCookie(String cookie) {
    _dio.options.headers['Cookie'] = cookie;
  }

  /// 拉取完整课表原始 JSON，自动合并分页结果。
  Future<Map<String, dynamic>> fetchGraduateScheduleRaw({
    required String semester,
  }) async {
    try {
      Map<String, dynamic>? merged;

      for (var pageNumber = 1; pageNumber <= _maxPages; pageNumber++) {
        final response = await _dio.post(
          _graduateSchedulePath,
          data: 'pageSize=$_pageSize&pageNumber=$pageNumber&XNXQDM=$semester',
        );

        if (response.statusCode != 200 || response.data is! Map) {
          throw ApiException('请求失败: HTTP ${response.statusCode}');
        }

        final pageData = Map<String, dynamic>.from(response.data as Map);
        if (pageData['code'] != '0') {
          throw ApiException('接口返回错误: code=${pageData['code']}，可能需要重新登录');
        }

        merged ??= pageData;
        if (pageNumber > 1) {
          _mergeRows(merged, pageData);
        }

        final rows = _extractRows(pageData);
        if (pageNumber == _maxPages &&
            rows != null &&
            rows.length >= _pageSize) {
          throw ApiException('课表分页超出安全上限，请调整分页策略');
        }
        if (rows == null || rows.length < _pageSize) {
          break;
        }
      }

      if (merged != null) {
        return merged;
      }
      throw ApiException('未获取到课程数据');
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiException('连接超时，请检查网络');
      }
      throw ApiException('网络错误: ${e.message}');
    }
  }

  /// 拉取解析后的课表。
  Future<List<Course>> fetchGraduateSchedule({required String semester}) async {
    final data = await fetchGraduateScheduleRaw(semester: semester);
    final courses = ScheduleParser.parseApiResponse(data);
    if (courses.isEmpty) {
      throw ApiException('未解析到课程数据，请检查是否有选课');
    }
    return courses;
  }

  /// 测试 Cookie 是否有效。
  Future<bool> testCookie({required String semester}) async {
    try {
      await fetchGraduateSchedule(semester: semester);
      return true;
    } catch (_) {
      return false;
    }
  }

  static List<dynamic>? _extractRows(Map<String, dynamic> root) {
    final datas = root['datas'];
    if (datas is! Map) return null;
    for (final value in datas.values) {
      if (value is Map && value['rows'] is List) {
        return value['rows'] as List<dynamic>;
      }
    }
    return null;
  }

  static void _mergeRows(
    Map<String, dynamic> target,
    Map<String, dynamic> incoming,
  ) {
    final targetRows = _extractRows(target);
    final incomingRows = _extractRows(incoming);
    if (targetRows == null || incomingRows == null || incomingRows.isEmpty) {
      return;
    }
    targetRows.addAll(incomingRows);
  }
}

/// API 异常
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}
