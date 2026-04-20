import 'package:dio/dio.dart';

import 'package:hai_schedule/services/login_expired_exception.dart';
import 'package:hai_schedule/services/portal_relogin_service.dart';
import 'package:hai_schedule/services/portal_session_expiry_detector.dart';

typedef SilentReloginCallback = Future<String> Function();

class DioClient {
  static const _retryAfterReloginKey = 'retry_after_relogin';
  static final Set<DioClient> _instances = <DioClient>{};

  DioClient({required BaseOptions options, SilentReloginCallback? reLogin})
    : _reLogin = reLogin ?? PortalReloginService.reLogin,
      _dio = Dio(options.copyWith(validateStatus: (status) => status != null)) {
    _instances.add(this);
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onResponse: (response, handler) async {
          if (!PortalSessionExpiryDetector.isExpiredResponse(response)) {
            handler.next(response);
            return;
          }

          if (_wasRetried(response.requestOptions)) {
            handler.reject(
              _buildExpiredException(response.requestOptions, response),
            );
            return;
          }

          await _retryAfterRelogin(
            requestOptions: response.requestOptions,
            responseHandler: handler,
            previousResponse: response,
          );
        },
        onError: (error, handler) async {
          if (!PortalSessionExpiryDetector.isExpiredError(error)) {
            handler.next(error);
            return;
          }

          if (_wasRetried(error.requestOptions)) {
            handler.reject(
              _buildExpiredException(error.requestOptions, error.response),
            );
            return;
          }

          await _retryAfterRelogin(
            requestOptions: error.requestOptions,
            errorHandler: handler,
            previousResponse: error.response,
          );
        },
      ),
    );
  }

  final Dio _dio;
  final SilentReloginCallback _reLogin;
  Future<String>? _pendingRelogin;
  String? _currentCookie;

  Dio get dio => _dio;

  String? get currentCookie => _currentCookie;

  static Future<void> clearAllSessions() async {
    for (final client in _instances) {
      client.clearSession();
    }
  }

  void updateCookie(String cookie) {
    _currentCookie = cookie;
    _dio.options.headers['Cookie'] = cookie;
  }

  void clearSession() {
    _pendingRelogin = null;
    _currentCookie = null;
    _dio.options.headers.remove('Cookie');
  }

  Future<void> _retryAfterRelogin({
    required RequestOptions requestOptions,
    ResponseInterceptorHandler? responseHandler,
    ErrorInterceptorHandler? errorHandler,
    Response<dynamic>? previousResponse,
  }) async {
    try {
      final cookie = await _resolveReloginCookie();
      final retryResponse = await _retryRequest(
        requestOptions: requestOptions,
        cookie: cookie,
      );

      if (PortalSessionExpiryDetector.isExpiredResponse(retryResponse)) {
        throw const LoginExpiredException();
      }

      responseHandler?.resolve(retryResponse);
      errorHandler?.resolve(retryResponse);
    } catch (e) {
      final exception =
          e is DioException
              ? e
              : DioException(
                requestOptions: requestOptions,
                response: previousResponse,
                type: DioExceptionType.badResponse,
                error: e,
              );
      responseHandler?.reject(exception);
      errorHandler?.reject(exception);
    }
  }

  Future<String> _resolveReloginCookie() async {
    final pending = _pendingRelogin;
    if (pending != null) {
      return pending;
    }

    final future = _reLogin();
    _pendingRelogin = future;
    try {
      final cookie = await future;
      updateCookie(cookie);
      return cookie;
    } finally {
      if (identical(_pendingRelogin, future)) {
        _pendingRelogin = null;
      }
    }
  }

  Future<Response<dynamic>> _retryRequest({
    required RequestOptions requestOptions,
    required String cookie,
  }) {
    final retryDio = Dio(_dio.options.copyWith());
    retryDio.httpClientAdapter = _dio.httpClientAdapter;
    return retryDio.fetch<dynamic>(
      requestOptions.copyWith(
        headers: Map<String, dynamic>.from(requestOptions.headers)
          ..['Cookie'] = cookie,
        extra: Map<String, dynamic>.from(requestOptions.extra)
          ..[_retryAfterReloginKey] = true,
      ),
    );
  }

  bool _wasRetried(RequestOptions requestOptions) {
    return requestOptions.extra[_retryAfterReloginKey] == true;
  }

  DioException _buildExpiredException(
    RequestOptions requestOptions,
    Response<dynamic>? response,
  ) {
    return DioException(
      requestOptions: requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      error: const LoginExpiredException(),
    );
  }
}
