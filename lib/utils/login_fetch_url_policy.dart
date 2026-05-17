class LoginFetchUrlPolicy {
  static const targetUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do';

  static const successPatterns = [
    'wdkbapp',
    'yjsemaphome',
    'portal/index.do',
    'jsxsd',
    'homepage',
  ];
  static const loginPatterns = ['cas', 'login', 'authserver'];

  static bool isLoginUrl(String url) {
    final urlLower = url.toLowerCase();
    return loginPatterns.any((pattern) => urlLower.contains(pattern));
  }

  static bool shouldAutoFetch(String url) {
    final urlLower = url.toLowerCase();
    final isLogin = loginPatterns.any((pattern) => urlLower.contains(pattern));
    final isTarget = successPatterns.any(
      (pattern) => urlLower.contains(pattern),
    );
    return isTarget && !isLogin;
  }
}
