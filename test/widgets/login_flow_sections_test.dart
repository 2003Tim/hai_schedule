import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/widgets/login_flow_sections.dart';

void main() {
  testWidgets('login flow header stays compact on small screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const longSemesterLabel = '2025-2026学年 第一学期 软件工程专业课表同步测试';

    await tester.pumpWidget(
      MaterialApp(
        home: LoginFlowScaffold(
          isFetching: false,
          canManualFetch: true,
          rememberPassword: true,
          activeCredential: const SavedPortalCredential(
            username: '2025123456',
            password: 'password',
          ),
          hasSavedCredential: true,
          selectedSemesterCode: '202520261',
          selectedSemesterLabel: longSemesterLabel,
          statusText: '正在加载登录页面...',
          onOpenCredentialEditor: () async {},
          onClearSavedCredential: () async {},
          onPickTargetSemester: () async {},
          onAutoFetch: () async {},
          onRememberPasswordChanged: (_) async {},
          content: const ColoredBox(color: Colors.black),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('同步课表'), findsOneWidget);
    expect(find.text('登录教务系统'), findsNothing);
    expect(find.text('手动抓取'), findsNothing);
    expect(find.textContaining(longSemesterLabel), findsOneWidget);
    expect(find.byTooltip('手动抓取'), findsOneWidget);
    expect(find.byTooltip('切换账号'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
