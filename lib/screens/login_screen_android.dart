import 'package:flutter/material.dart';

import '../widgets/login_webview_adapters.dart';
import 'login_flow_state_mixin.dart';

class LoginScreenAndroid extends StatefulWidget {
  const LoginScreenAndroid({
    super.key,
    this.initialSemesterCode,
    this.openCredentialEditor = false,
  });

  final String? initialSemesterCode;
  final bool openCredentialEditor;

  @override
  State<LoginScreenAndroid> createState() => _LoginScreenAndroidState();
}

class _LoginScreenAndroidState extends State<LoginScreenAndroid>
    with LoginFlowStateMixin<LoginScreenAndroid> {
  @override
  String get bridgeCall => 'FlutterBridge.postMessage';

  @override
  Duration get autoFetchWarmupDelay => const Duration(seconds: 2);

  @override
  String get initialStatusText => '正在加载登录页面...';

  @override
  String? get initialSemesterCode => widget.initialSemesterCode;

  @override
  bool get shouldOpenCredentialEditor => widget.openCredentialEditor;

  @override
  LoginWebviewAdapter createWebviewAdapter() => AndroidLoginWebviewAdapter();

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
    return buildLoginFlowPage();
  }
}
