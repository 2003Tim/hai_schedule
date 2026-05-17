import 'package:flutter/material.dart';

import 'package:hai_schedule/screens/login_screen.dart';
import 'package:hai_schedule/screens/login_screen_android.dart';
import 'package:hai_schedule/utils/app_platform.dart';

class LoginRouter extends StatelessWidget {
  const LoginRouter({
    super.key,
    this.initialSemesterCode,
    this.openCredentialEditor = false,
  });

  final String? initialSemesterCode;
  final bool openCredentialEditor;

  @override
  Widget build(BuildContext context) {
    if (AppPlatform.instance.isWindows) {
      return LoginScreen(
        initialSemesterCode: initialSemesterCode,
        openCredentialEditor: openCredentialEditor,
      );
    }
    return LoginScreenAndroid(
      initialSemesterCode: initialSemesterCode,
      openCredentialEditor: openCredentialEditor,
    );
  }
}
