import 'package:flutter/material.dart';

import 'package:hai_schedule/models/schedule_source.dart';
import 'package:hai_schedule/screens/login_screen.dart';
import 'package:hai_schedule/screens/login_screen_android.dart';
import 'package:hai_schedule/utils/app_platform.dart';

class LoginRouter extends StatelessWidget {
  const LoginRouter({
    super.key,
    this.initialSemesterCode,
    this.openCredentialEditor = false,
    this.source = ScheduleSource.graduate,
  });

  final String? initialSemesterCode;
  final bool openCredentialEditor;
  final ScheduleSource source;

  @override
  Widget build(BuildContext context) {
    if (AppPlatform.instance.isWindows) {
      return LoginScreen(
        initialSemesterCode: initialSemesterCode,
        openCredentialEditor: openCredentialEditor,
        source: source,
      );
    }
    return LoginScreenAndroid(
      initialSemesterCode: initialSemesterCode,
      openCredentialEditor: openCredentialEditor,
      source: source,
    );
  }
}
