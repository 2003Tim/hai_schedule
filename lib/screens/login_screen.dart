import 'package:flutter/material.dart';

import 'package:hai_schedule/screens/login_flow_state_mixin.dart';
import 'package:hai_schedule/widgets/login_webview_adapters.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialSemesterCode,
    this.openCredentialEditor = false,
  });

  final String? initialSemesterCode;
  final bool openCredentialEditor;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with LoginFlowStateMixin<LoginScreen> {
  @override
  String get bridgeCall => 'window.chrome.webview.postMessage';

  @override
  Duration get autoFetchWarmupDelay => const Duration(seconds: 3);

  @override
  String get initialStatusText => '正在初始化浏览器...';

  @override
  String? get readyStatusText => '请登录教务系统';

  @override
  String? get initialSemesterCode => widget.initialSemesterCode;

  @override
  bool get shouldOpenCredentialEditor => widget.openCredentialEditor;

  @override
  LoginWebviewAdapter createWebviewAdapter() => WindowsLoginWebviewAdapter();

  @override
  void initState() {
    super.initState();
    initLoginFlow();
  }

  @override
  void dispose() {
    disposeLoginFlow();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildLoginFlowPage(
      activeBackgroundColor: Colors.blue.withValues(alpha: 0.1),
      idleBackgroundColor: Colors.grey.withValues(alpha: 0.05),
      statusTextStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
    );
  }
}
