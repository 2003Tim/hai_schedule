import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/screens/app_launch_splash_screen.dart';

void main() {
  testWidgets('launch splash image covers the full viewport', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppLaunchSplashScreen()));

    final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
    expect(fittedBox.fit, BoxFit.cover);
    expect(find.byType(Padding), findsNothing);
  });
}
