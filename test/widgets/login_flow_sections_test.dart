import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/services/auth_credentials_service.dart';
import 'package:hai_schedule/widgets/login_flow_sections.dart';

void main() {
  Widget buildTestApp({
    required Size size,
    required SavedPortalCredential? savedCredential,
  }) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: LoginFlowScaffold(
          isFetching: false,
          canManualFetch: true,
          rememberPassword: false,
          savedCredential: savedCredential,
          selectedSemesterCode: null,
          statusText: 'status',
          onOpenCredentialEditor: () async {},
          onClearSavedCredential: () async {},
          onPickTargetSemester: () async {},
          onAutoFetch: () async {},
          onRememberPasswordChanged: (_) async {},
          content: const SizedBox.shrink(),
        ),
      ),
    );
  }

  testWidgets('uses overflow menu on compact widths', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        size: const Size(390, 844),
        savedCredential: const SavedPortalCredential(
          username: 'student',
          password: 'secret',
        ),
      ),
    );

    expect(find.byKey(const ValueKey('loginFlowOverflowMenu')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('loginFlowManageCredentialAction')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('loginFlowPickSemesterAction')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('loginFlowManualFetchAction')),
      findsNothing,
    );
  });

  testWidgets('keeps inline actions on wider layouts', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        size: const Size(900, 700),
        savedCredential: const SavedPortalCredential(
          username: 'student',
          password: 'secret',
        ),
      ),
    );

    expect(find.byKey(const ValueKey('loginFlowOverflowMenu')), findsNothing);
    expect(
      find.byKey(const ValueKey('loginFlowManageCredentialAction')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('loginFlowClearCredentialAction')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('loginFlowPickSemesterAction')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('loginFlowManualFetchAction')),
      findsOneWidget,
    );
  });
}
