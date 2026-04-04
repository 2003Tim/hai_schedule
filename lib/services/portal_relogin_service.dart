import 'package:flutter/material.dart';

import 'package:hai_schedule/screens/login_router.dart';
import 'package:hai_schedule/services/auth_credentials_service.dart';

class PortalReloginService {
  PortalReloginService._();

  static Future<bool> hasSavedCredential() async {
    return await AuthCredentialsService.instance.load() != null;
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
