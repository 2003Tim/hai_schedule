import 'package:flutter_test/flutter_test.dart';

import 'package:hai_schedule/models/login_fetch_coordinator_models.dart';
import 'package:hai_schedule/utils/login_flow_autofill_controller.dart';

void main() {
  group('LoginFlowAutofillController', () {
    test(
      'starts loop, increments attempts and enables autosubmit from third try',
      () {
        final controller = LoginFlowAutofillController();
        var triggered = false;

        controller.start(() {
          triggered = true;
        });

        expect(triggered, isTrue);
        expect(controller.loopActive, isTrue);
        expect(controller.pendingAutofill, isTrue);

        controller.beginAttempt();
        expect(controller.shouldAutoSubmit, isFalse);
        expect(controller.nextRetryDelay(), const Duration(milliseconds: 1100));

        controller.beginAttempt();
        expect(controller.shouldAutoSubmit, isFalse);
        expect(controller.nextRetryDelay(), const Duration(milliseconds: 1500));

        controller.beginAttempt();
        expect(controller.shouldAutoSubmit, isTrue);
        expect(controller.nextRetryDelay(), const Duration(milliseconds: 1500));
      },
    );

    test(
      'applies terminal resolution and clears pending state when required',
      () {
        final controller = LoginFlowAutofillController();
        controller.start(() {});

        controller.handleResolution(
          const LoginAutofillStateResolution(
            statusText: 'done',
            stopAutofillLoop: true,
            clearPendingAutofill: true,
          ),
        );

        expect(controller.loopActive, isFalse);
        expect(controller.pendingAutofill, isFalse);
      },
    );

    test(
      'exhaustPending returns whether incomplete status should be shown',
      () {
        final controller = LoginFlowAutofillController();
        controller.start(() {});

        expect(controller.exhaustPending(), isTrue);
        expect(controller.loopActive, isFalse);
        expect(controller.pendingAutofill, isFalse);

        controller.setPending(false);
        expect(controller.exhaustPending(), isFalse);
      },
    );
  });
}
