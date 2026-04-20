class LoginExpiredException implements Exception {
  static const String defaultMessage = '登录已失效，请点击下方“登录并刷新课表”重连';

  final String message;

  const LoginExpiredException([this.message = defaultMessage]);

  @override
  String toString() => message;
}
