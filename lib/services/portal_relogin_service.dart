import 'package:flutter/material.dart';

import 'package:hai_schedule/screens/login_router.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/services/login_expired_exception.dart';
import 'package:hai_schedule/services/portal_http_login_service.dart';

class PortalReloginService {
  PortalReloginService._();

  static Future<bool> hasSavedCredential() async {
    return await AuthCredentialsService.instance.load() != null;
  }

  static Future<String> reLogin({
    AuthCredentialsService? credentialsService,
    Future<String> Function(SavedPortalCredential credential)? performLogin,
  }) async {
    final resolvedCredentialsService =
        credentialsService ?? AuthCredentialsService.instance;
    final credential = await resolvedCredentialsService.load();
    if (credential == null) {
      throw const LoginExpiredException();
    }

    return await (performLogin?.call(credential) ??
        PortalHttpLoginService().loginWithCredential(credential));
  }

  static Future<bool> tryRelogin(
    BuildContext context, {
    String? semesterCode,
  }) async {
    final credential = await AuthCredentialsService.instance.load();
    if (credential == null) return false;

    if (!context.mounted) return false;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoginRouter(initialSemesterCode: semesterCode),
      ),
    );
    return result == true;
  }
}
