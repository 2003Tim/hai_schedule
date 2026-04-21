import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:hai_schedule/services/dio_client.dart';
import 'package:hai_schedule/services/invalid_credentials_exception.dart';
import 'package:hai_schedule/services/login_expired_exception.dart';
import 'package:hai_schedule/services/portal_session_expiry_detector.dart';

class PortalPageResult {
  final String body;
  final String? contentType;

  const PortalPageResult({required this.body, this.contentType});
}

/// 教务系统 API 服务
class ApiService {
  static const _baseUrl = 'https://ehall.hainanu.edu.cn';
  static const _indexUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do';
  static const _graduateSchedulePath =
      '/gsapp/sys/wdkbapp/modules/xskcb/xsjxrwcx.do';
  static const _pageSize = 100;
  static const _maxPages = 20;

  ApiService({String? cookie, DioClient? dioClient})
    : _client =
          dioClient ??
          DioClient(
            options: BaseOptions(
              baseUrl: _baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              headers: {
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=UTF-8',
                'X-Requested-With': 'XMLHttpRequest',
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'Origin': _baseUrl,
                'Referer': _indexUrl,
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
                'Accept-Language': 'zh-CN,zh;q=0.9',
                if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
              },
            ),
          ) {
    _dio = _client.dio;
    if (cookie != null && cookie.isNotEmpty) {
      updateCookie(cookie);
    }
  }

  final DioClient _client;
  late final Dio _dio;

  String? get currentCookie => _client.currentCookie;

  /// 更新 Cookie
  void updateCookie(String cookie) {
    _client.updateCookie(cookie);
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

        if (PortalSessionExpiryDetector.isExpiredResponse(response)) {
          throw const LoginExpiredException();
        }

        if (response.statusCode != 200) {
          throw ApiException('请求失败: HTTP ${response.statusCode}');
        }

        final pageData = _readJsonMap(response.data);
        if (_isLoginExpiredPayload(pageData)) {
          throw const LoginExpiredException();
        }

        if (pageData['code']?.toString() != '0') {
          throw ApiException('接口返回错误: code=${pageData['code']}');
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
      if (e.error is LoginExpiredException) {
        throw e.error as LoginExpiredException;
      }
      if (e.error is InvalidCredentialsException) {
        throw e.error as InvalidCredentialsException;
      }
      if (e.response != null &&
          PortalSessionExpiryDetector.isExpiredResponse(e.response!)) {
        throw const LoginExpiredException();
      }
      if (e.response?.statusCode != null) {
        throw ApiException('请求失败: HTTP ${e.response!.statusCode}');
      }
      throw ApiException('网络错误: ${e.message}');
    }
  }

  Future<PortalPageResult> fetchPortalHomePage() async {
    try {
      final response = await _dio.getUri<String>(
        Uri.parse(_indexUrl),
        options: Options(
          responseType: ResponseType.plain,
          headers: <String, dynamic>{
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );

      if (PortalSessionExpiryDetector.isExpiredResponse(response)) {
        throw const LoginExpiredException();
      }

      if (response.statusCode != 200) {
        throw ApiException('请求失败: HTTP ${response.statusCode}');
      }

      final body = response.data;
      if (body == null || body.trim().isEmpty) {
        throw ApiException('教务主页返回空响应');
      }

      return PortalPageResult(
        body: body,
        contentType: response.headers.value(Headers.contentTypeHeader),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiException('连接超时，请检查网络');
      }
      if (e.error is LoginExpiredException) {
        throw e.error as LoginExpiredException;
      }
      if (e.error is InvalidCredentialsException) {
        throw e.error as InvalidCredentialsException;
      }
      if (e.response != null &&
          PortalSessionExpiryDetector.isExpiredResponse(e.response!)) {
        throw const LoginExpiredException();
      }
      if (e.response?.statusCode != null) {
        throw ApiException('请求失败: HTTP ${e.response!.statusCode}');
      }
      throw ApiException('网络错误: ${e.message}');
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

  static Map<String, dynamic> _readJsonMap(dynamic data) {
    if (PortalSessionExpiryDetector.isExpiredBody(data)) {
      throw const LoginExpiredException();
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        throw ApiException('课表接口返回空响应');
      }

      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        throw ApiException('课表接口返回了非 JSON 数据');
      }
    }

    throw ApiException('课表接口返回了非 JSON 数据');
  }

  static bool _isLoginExpiredPayload(Map<String, dynamic> payload) {
    final message =
        payload['msg']?.toString() ?? payload['message']?.toString() ?? '';
    return PortalSessionExpiryDetector.isExpiredStatusCode(
          int.tryParse(payload['code']?.toString() ?? ''),
        ) ||
        PortalSessionExpiryDetector.isExpiredBody(message);
  }
}

/// API 异常
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}
