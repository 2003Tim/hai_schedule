import 'package:dio/dio.dart';

import 'package:hai_schedule/services/api_service.dart';
import 'package:hai_schedule/services/app_repositories.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/invalid_credentials_exception.dart';
import 'package:hai_schedule/services/login_expired_exception.dart';

class PortalHttpLoginService {
  static const _indexUrl =
      'https://ehall.hainanu.edu.cn/gsapp/sys/wdkbapp/*default/index.do';
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36';

  PortalHttpLoginService({SyncRepository? syncRepository})
    : _syncRepository = syncRepository ?? SyncRepository();

  final SyncRepository _syncRepository;

  Future<String> loginWithCredential(SavedPortalCredential credential) async {
    final cookies = <String, String>{};

    try {
      final indexPage = await _openRequest(
        url: _indexUrl,
        cookieJar: cookies,
        followRedirects: true,
      );

      final form = _parseLoginForm(indexPage.url, indexPage.body);
      if (form == null) {
        throw ApiException('静默登录失败：未能解析登录表单');
      }

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

      final loginBody = fields.entries
          .map((entry) => '${_urlEncode(entry.key)}=${_urlEncode(entry.value)}')
          .join('&');

      final loginResultPage = await _openRequest(
        url: form.actionUrl,
        method: 'POST',
        body: loginBody,
        referer: indexPage.url,
        cookieJar: cookies,
        followRedirects: true,
      );
      if (_containsInvalidCredentialError(loginResultPage.body)) {
        throw const InvalidCredentialsException();
      }

      final verifyPage = await _openRequest(
        url: _indexUrl,
        referer: form.actionUrl,
        cookieJar: cookies,
        followRedirects: true,
      );
      if (_containsInvalidCredentialError(verifyPage.body)) {
        throw const InvalidCredentialsException();
      }

      final verifyUrl = verifyPage.url.toLowerCase();
      final loginStillRequired =
          verifyUrl.contains('authserver') ||
          verifyUrl.contains('login') ||
          _isMultiFactorChallenge(verifyPage.body);
      if (loginStillRequired) {
        throw const LoginExpiredException();
      }

      final mergedCookie = cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
      if (mergedCookie.isEmpty) {
        throw const LoginExpiredException();
      }

      await _syncRepository.saveCookieSnapshot(mergedCookie);
      return mergedCookie;
    } on LoginExpiredException {
      rethrow;
    } on InvalidCredentialsException {
      rethrow;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiException('静默登录超时，请检查网络后重试');
      }
      throw ApiException('静默登录失败: ${e.message}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('静默登录失败: $e');
    }
  }

  Future<_PortalResponse> _openRequest({
    required String url,
    required Map<String, String> cookieJar,
    String method = 'GET',
    String? body,
    String? referer,
    bool followRedirects = false,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    var currentUrl = url;
    var currentMethod = method;
    var currentBody = body;
    var currentReferer = referer;

    for (var redirectCount = 0; redirectCount < 8; redirectCount++) {
      final response = await dio.request<dynamic>(
        currentUrl,
        data: currentMethod == 'POST' ? currentBody : null,
        options: Options(
          method: currentMethod,
          headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'zh-CN,zh;q=0.9',
            if (currentMethod == 'POST')
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
            if (currentReferer != null) 'Referer': currentReferer,
            if (cookieJar.isNotEmpty)
              'Cookie': cookieJar.entries
                  .map((entry) => '${entry.key}=${entry.value}')
                  .join('; '),
          },
        ),
      );

      _extractCookies(response.headers, cookieJar);

      if (followRedirects &&
          response.statusCode != null &&
          response.statusCode! >= 300 &&
          response.statusCode! < 400) {
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          currentReferer = currentUrl;
          currentUrl = _resolveUrl(currentUrl, location);
          currentMethod = 'GET';
          currentBody = null;
          continue;
        }
      }

      final responseBody =
          response.data is String
              ? response.data as String
              : response.data.toString();
      return _PortalResponse(
        url: currentUrl,
        statusCode: response.statusCode ?? 200,
        body: responseBody,
      );
    }

    throw ApiException('静默登录失败：重定向次数过多');
  }

  void _extractCookies(Headers headers, Map<String, String> cookieJar) {
    final setCookie = headers['set-cookie'];
    if (setCookie == null) return;

    for (final raw in setCookie) {
      final part = raw.split(';').first.trim();
      final index = part.indexOf('=');
      if (index <= 0) continue;
      final key = part.substring(0, index).trim();
      final value = part.substring(index + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      cookieJar[key] = value;
    }
  }

  _PortalLoginForm? _parseLoginForm(String pageUrl, String html) {
    final formRegex = RegExp(
      '<form[^>]*action=["\']([^"\']+)["\'][^>]*>([\\s\\S]*?)</form>',
      caseSensitive: false,
    );

    for (final match in formRegex.allMatches(html)) {
      final action = match.group(1);
      final formHtml = match.group(2);
      if (action == null || formHtml == null) {
        continue;
      }

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

      return _PortalLoginForm(
        actionUrl: _resolveUrl(pageUrl, action),
        hiddenFields: hiddenFields,
      );
    }

    return null;
  }

  bool _isMultiFactorChallenge(String html) {
    final lower = html.toLowerCase();
    return lower.contains('多因子认证') ||
        lower.contains('right-header-title') ||
        lower.contains('dynamiccode') ||
        lower.contains('reauthsubmitbtn');
  }

  bool _containsInvalidCredentialError(String html) {
    if (html.trim().isEmpty) return false;
    final lower = html.toLowerCase();
    return lower.contains('用户名或密码错误') ||
        lower.contains('账号或密码错误') ||
        lower.contains('用户名密码错误') ||
        lower.contains('密码错误') ||
        lower.contains('bad credentials') ||
        lower.contains('invalid credentials');
  }

  String? _findAttr(String tag, String name) {
    final regex = RegExp(
      '$name\\s*=\\s*["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    final match = regex.firstMatch(tag);
    return match?.group(1);
  }

  String _resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }
    return Uri.parse(baseUrl).resolve(relativeUrl).toString();
  }

  String _urlEncode(String value) => Uri.encodeComponent(value);
}

class _PortalResponse {
  final String url;
  final int statusCode;
  final String body;

  _PortalResponse({
    required this.url,
    required this.statusCode,
    required this.body,
  });
}

class _PortalLoginForm {
  final String actionUrl;
  final Map<String, String> hiddenFields;

  _PortalLoginForm({required this.actionUrl, required this.hiddenFields});
}
