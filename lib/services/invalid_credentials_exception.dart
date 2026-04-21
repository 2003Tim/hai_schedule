class InvalidCredentialsException implements Exception {
  static const defaultMessage = '登录失败：密码错误，请手动重新关联';

  final String message;

  const InvalidCredentialsException([this.message = defaultMessage]);

  @override
  String toString() => message;
}
