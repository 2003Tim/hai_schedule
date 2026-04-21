class PortalRedirectException implements Exception {
  static const String defaultMessage = '教务系统返回了非网页内容，请重新登录后再试';

  final String message;

  const PortalRedirectException([this.message = defaultMessage]);

  @override
  String toString() => message;
}
