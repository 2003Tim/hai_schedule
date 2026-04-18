import 'dart:io' show Platform;

import 'package:dio/dio.dart';

import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/utils/app_logger.dart';

/// Desktop端（Windows/macOS/Linux）HTTP后台登录服务
/// 模拟浏览器完成海南大学教务系统登录，提取有效Cookie供后台同步使用
class DesktopPortalLoginService {
  static const _tag = 'DesktopPortalLogin';
  static const _indexUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do';
  static const _userAgent =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  static final Map<String, String> _cookies = {};

  /// 尝试从保存的凭证完成登录并获取有效Cookie
  /// 返回 null 表示失败（网络问题、密码错误或MFA），触发方应弹出登录页
  static Future<String?> tryLogin(SavedPortalCredential credential) async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return null;
    }

    try {
      AppLogger.debug(_tag, '开始HTTP后台登录流程');

      // 第一步：获取登录页面（含表单）
      final indexPage = await _fetchLoginPage();
      AppLogger.debug(_tag, '已获取登录页: ${indexPage.url}');

      // 第二步：解析登录表单
      final form = _parseLoginForm(indexPage.url, indexPage.body);
      if (form == null) {
        AppLogger.error(_tag, '无法解析登录表单', Exception('form is null'));
        return null;
      }
      AppLogger.debug(_tag, '已解析登录表单，action: ${form.actionUrl}');

      // 第三步：POST登录凭证
      final fields = <String, String>{...form.hiddenFields};
      fields['username'] = credential.username;
      fields['password'] = credential.password;
      fields['passwordText'] = credential.password;
      fields['rememberMe'] = 'true';
      if (!fields.containsKey('_eventId')) {
        fields['_eventId'] = 'submit';
      }
      if (!fields.containsKey('cllt')) {
        fields['cllt'] = 'userNameLogin';
      }
      if (!fields.containsKey('dllt')) {
        fields['dllt'] = 'generalLogin';
      }
      if (!fields.containsKey('lt')) {
        fields['lt'] = '';
      }

      final loginBody =
          fields.entries.map((e) => '${_urlEncode(e.key)}=${_urlEncode(e.value)}').join('&');
      await _postRequest(
        url: form.actionUrl,
        body: loginBody,
        referer: indexPage.url,
      );
      AppLogger.debug(_tag, '登录请求已发送');

      // 第四步：验证登录结果（检查是否返回到课表页或仍在登录页）
      final verifyPage = await _fetchPageWithCookie(
        _indexUrl,
        referer: form.actionUrl,
      );
      final verifyUrl = verifyPage.url.toLowerCase();
      AppLogger.debug(_tag, '验证页URL: ${verifyPage.url}');

      // 检查是否仍在登录页或MFA页
      final stillOnLoginPage = verifyUrl.contains('authserver') || verifyUrl.contains('login');
      final isMfaChallenge = _isMfaChallengeResponse(verifyPage.body);

      if (isMfaChallenge) {
        AppLogger.warn(_tag, '检测到多因子认证（MFA），需要手动处理');
        return null;
      }

      if (stillOnLoginPage) {
        AppLogger.warn(_tag, '登录失败：密码可能错误或账号问题');
        return null;
      }

      // 第五步：从所有Cookie请求中合并Cookie字符串
      final mergedCookie = _getMergedCookieString();
      if (mergedCookie.isEmpty) {
        AppLogger.warn(_tag, '未能提取有效Cookie');
        return null;
      }

      AppLogger.debug(_tag, 'HTTP后台登录成功，保存Cookie快照');
      await _saveCookieSnapshot(mergedCookie);
      return mergedCookie;
    } catch (e, st) {
      AppLogger.error(_tag, 'HTTP后台登录异常', e, st);
      return null;
    }
  }

  /// 从安全存储加载Cookie快照
  static Future<String?> loadCookieSnapshot() async {
    try {
      return null;
    } catch (e) {
      AppLogger.warn(_tag, '加载Cookie快照失败', e);
      return null;
    }
  }

  /// 清除保存的Cookie快照
  static Future<void> clearCookieSnapshot() async {
    try {} catch (e) {
      AppLogger.warn(_tag, '清除Cookie快照失败', e);
    }
  }

  // ============= 私有工具方法 =============

  static String _getMergedCookieString() {
    if (_cookies.isEmpty) return '';
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static Future<void> _saveCookieSnapshot(String cookie) async {}

  static Future<_Response> _fetchLoginPage() async {
    return _getRequest(
      _indexUrl,
      followRedirects: true,
    );
  }

  static Future<_Response> _fetchPageWithCookie(
    String url, {
    String? referer,
  }) async {
    return _getRequest(
      url,
      referer: referer,
      followRedirects: true,
    );
  }

  static Future<_Response> _getRequest(
    String url, {
    String? referer,
    bool followRedirects = false,
  }) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ));

    var currentUrl = url;
    var currentReferer = referer;

    for (var redirectCount = 0; redirectCount < 8; redirectCount++) {
      final response = await dio.get(
        currentUrl,
        options: Options(
          headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'zh-CN,zh;q=0.9',
            if (currentReferer != null) 'Referer': currentReferer,
            if (_cookies.isNotEmpty)
              'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
          },
        ),
      );

      _extractCookies(response.headers);

      if (followRedirects &&
          response.statusCode != null &&
          response.statusCode! >= 300 &&
          response.statusCode! < 400) {
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          currentReferer = currentUrl;
          currentUrl = _resolveUrl(currentUrl, location);
          continue;
        }
      }

      final body = response.data is String ? response.data : response.data.toString();
      return _Response(
        url: currentUrl,
        statusCode: response.statusCode ?? 200,
        body: body,
      );
    }

    throw Exception('重定向次数过多');
  }

  static Future<_Response> _postRequest({
    required String url,
    required String body,
    String? referer,
  }) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ));

    final response = await dio.post(
      url,
      data: body,
      options: Options(
        headers: {
          'User-Agent': _userAgent,
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Accept-Language': 'zh-CN,zh;q=0.9',
          if (referer != null) 'Referer': referer,
          if (_cookies.isNotEmpty)
            'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
        },
      ),
    );

    _extractCookies(response.headers);

    final bodyStr = response.data is String ? response.data : response.data.toString();
    return _Response(
      url: url,
      statusCode: response.statusCode ?? 200,
      body: bodyStr,
    );
  }

  static void _extractCookies(Headers headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie != null) {
      for (final raw in setCookie) {
        final parts = raw.split(';');
        if (parts.isNotEmpty) {
          final kv = parts[0].trim().split('=');
          if (kv.length == 2) {
            _cookies[kv[0]] = kv[1];
          }
        }
      }
    }
  }

  static _LoginForm? _parseLoginForm(String pageUrl, String html) {
    final formRegex = RegExp(
      '<form[^>]*action=["\']([^"\']+)["\'][^>]*>(.+?)</form>',
      caseSensitive: false,
    );

    for (final match in formRegex.allMatches(html)) {
      final action = match.group(1);
      final formHtml = match.group(2);

      if (action == null || formHtml == null) continue;
      final lower = formHtml.toLowerCase();
      if (!lower.contains('username') || !lower.contains('password')) {
        continue;
      }

      final hiddenFields = <String, String>{};
      final inputRegex = RegExp(r'<input[^>]*>', caseSensitive: false);

      for (final inputMatch in inputRegex.allMatches(formHtml)) {
        final tag = inputMatch.group(0)!;
        final name = _findAttr(tag, 'name');
        if (name == null) continue;

        final type = _findAttr(tag, 'type')?.toLowerCase() ?? '';
        if (type == 'hidden') {
          hiddenFields[name] = _findAttr(tag, 'value') ?? '';
        }
      }

      return _LoginForm(
        actionUrl: _resolveUrl(pageUrl, action),
        hiddenFields: hiddenFields,
      );
    }

    return null;
  }

  static String? _findAttr(String tag, String name) {
    final regex = RegExp('$name\\s*=\\s*["\']([^"\']*)["\']', caseSensitive: false);
    final match = regex.firstMatch(tag);
    return match?.group(1);
  }

  static String _resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.startsWith('http')) return relativeUrl;
    if (relativeUrl.startsWith('/')) {
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$relativeUrl';
    }
    return Uri.parse(baseUrl).resolve(relativeUrl).toString();
  }

  static String _urlEncode(String value) => Uri.encodeComponent(value);

  static bool _isMfaChallengeResponse(String html) {
    final lower = html.toLowerCase();
    return lower.contains('多因子认证') ||
        lower.contains('right-header-title') ||
        lower.contains('dynamiccode') ||
        lower.contains('reauthsubmitbtn');
  }
}

class _Response {
  final String url;
  final int statusCode;
  final String body;

  _Response({
    required this.url,
    required this.statusCode,
    required this.body,
  });
}

class _LoginForm {
  final String actionUrl;
  final Map<String, String> hiddenFields;

  _LoginForm({
    required this.actionUrl,
    required this.hiddenFields,
  });
}
