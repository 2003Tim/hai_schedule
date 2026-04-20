import 'package:dio/dio.dart';

class PortalSessionExpiryDetector {
  const PortalSessionExpiryDetector._();

  static bool isExpiredResponse(Response<dynamic> response) {
    return isExpiredStatusCode(response.statusCode) ||
        isExpiredBody(response.data);
  }

  static bool isExpiredError(DioException error) {
    final response = error.response;
    if (response != null && isExpiredResponse(response)) {
      return true;
    }

    return isExpiredStatusCode(response?.statusCode) ||
        isExpiredBody(error.error) ||
        isExpiredBody(error.message);
  }

  static bool isExpiredStatusCode(int? statusCode) {
    return statusCode == 401 || statusCode == 403;
  }

  static bool isExpiredBody(dynamic body) {
    if (body == null) return false;
    final text = body.toString().toLowerCase();
    if (text.isEmpty) return false;
    return text.contains('not login!') || text.contains('not login');
  }
}
