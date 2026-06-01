import 'package:flutter/material.dart';

import 'package:hai_schedule/services/app_storage.dart';
import 'package:hai_schedule/screens/login_router.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/login_expired_exception.dart';
import 'package:hai_schedule/services/portal_http_login_service.dart';

class PortalReloginService {
  PortalReloginService._();

  static Future<bool> hasSavedCredential() async {
    final source = await AppStorage.instance.loadActiveScheduleSource();
    return await AuthCredentialsService.instance.load(source: source) != null;
  }

  static Future<String> reLogin({
    AuthCredentialsService? credentialsService,
    Future<String> Function(SavedPortalCredential credential)? performLogin,
  }) async {
    final resolvedCredentialsService =
        credentialsService ?? AuthCredentialsService.instance;
    final source = await AppStorage.instance.loadActiveScheduleSource();
    final credential = await resolvedCredentialsService.load(source: source);
    if (credential == null) {
      throw const LoginExpiredException();
    }

    // Undergraduate (jxgl) login is interactive (WebView + captcha) and cannot
    // be silently replayed via PortalHttpLoginService — that service only
    // knows the graduate ehall CAS form. Without a source-aware performLogin
    // override the safe action is to surface LoginExpired so callers route
    // the user through the WebView LoginRouter instead of posting the
    // undergraduate credential at the wrong endpoint and persisting a
    // mismatched cookie under the undergraduate storage slot.
    if (source.isUndergraduate && performLogin == null) {
      throw const LoginExpiredException();
    }

    return await (performLogin?.call(credential) ??
        PortalHttpLoginService().loginWithCredential(credential));
  }

  static Future<bool> tryRelogin(
    BuildContext context, {
    String? semesterCode,
  }) async {
    final source = await AppStorage.instance.loadActiveScheduleSource();
    final credential = await AuthCredentialsService.instance.load(
      source: source,
    );
    if (credential == null) return false;

    if (!context.mounted) return false;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) =>
                LoginRouter(initialSemesterCode: semesterCode, source: source),
      ),
    );
    return result == true;
  }
}
