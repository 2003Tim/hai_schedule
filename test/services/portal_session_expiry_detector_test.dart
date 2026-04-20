import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/services/portal_session_expiry_detector.dart';

void main() {
  group('PortalSessionExpiryDetector', () {
    test('detects expired responses by 401 or 403 status code', () {
      expect(
        PortalSessionExpiryDetector.isExpiredResponse(
          _buildResponse(statusCode: 401, data: '{"code":"0"}'),
        ),
        isTrue,
      );
      expect(
        PortalSessionExpiryDetector.isExpiredResponse(
          _buildResponse(statusCode: 403, data: '{"code":"0"}'),
        ),
        isTrue,
      );
    });

    test('detects expired responses by Not login html body', () {
      expect(
        PortalSessionExpiryDetector.isExpiredResponse(
          _buildResponse(
            statusCode: 200,
            data:
                '<!DOCTYPE html><html><body><h1>Not login!</h1></body></html>',
          ),
        ),
        isTrue,
      );
      expect(
        PortalSessionExpiryDetector.isExpiredResponse(
          _buildResponse(
            statusCode: 200,
            data: '<html><body>redirecting... not login</body></html>',
          ),
        ),
        isTrue,
      );
    });

    test('does not mark regular success response as expired', () {
      expect(
        PortalSessionExpiryDetector.isExpiredResponse(
          _buildResponse(statusCode: 200, data: '{"code":"0"}'),
        ),
        isFalse,
      );
      expect(
        PortalSessionExpiryDetector.isExpiredBody(
          '<html><body>ok</body></html>',
        ),
        isFalse,
      );
    });

    test('detects DioException carrying expired response or message', () {
      final requestOptions = RequestOptions(path: '/schedule');
      final expiredResponse = _buildResponse(
        statusCode: 401,
        data: '<html><body>Not login!</body></html>',
        requestOptions: requestOptions,
      );

      expect(
        PortalSessionExpiryDetector.isExpiredError(
          DioException(
            requestOptions: requestOptions,
            response: expiredResponse,
            type: DioExceptionType.badResponse,
          ),
        ),
        isTrue,
      );

      expect(
        PortalSessionExpiryDetector.isExpiredError(
          DioException(
            requestOptions: requestOptions,
            type: DioExceptionType.unknown,
            message: 'server says Not login!',
          ),
        ),
        isTrue,
      );
    });
  });
}

Response<dynamic> _buildResponse({
  required int statusCode,
  required dynamic data,
  RequestOptions? requestOptions,
}) {
  return Response<dynamic>(
    requestOptions: requestOptions ?? RequestOptions(path: '/schedule'),
    statusCode: statusCode,
    data: data,
  );
}
