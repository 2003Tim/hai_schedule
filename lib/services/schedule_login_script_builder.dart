import 'package:hai_schedule/utils/schedule_login_autofill_script.dart';
import 'package:hai_schedule/utils/schedule_login_semester_scripts.dart';

class ScheduleLoginScriptBuilder {
  static const apiUrl = ScheduleLoginSemesterScripts.apiUrl;

  static String buildDetectSemesterScript({
    required String bridgeCall,
    required String requestId,
  }) => ScheduleLoginSemesterScripts.buildDetectSemesterScript(
    bridgeCall: bridgeCall,
    requestId: requestId,
  );

  static String buildFetchScheduleScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) => ScheduleLoginSemesterScripts.buildFetchScheduleScript(
    bridgeCall: bridgeCall,
    semester: semester,
    requestId: requestId,
  );

  static String buildSwitchSemesterScript({
    required String bridgeCall,
    required String semester,
    required String requestId,
  }) => ScheduleLoginSemesterScripts.buildSwitchSemesterScript(
    bridgeCall: bridgeCall,
    semester: semester,
    requestId: requestId,
  );

  static String buildFillCredentialScript({
    required String username,
    required String password,
    String? bridgeCall,
    bool autoSubmit = true,
    bool enableTrustOption = true,
  }) => ScheduleLoginAutofillScript.build(
    username: username,
    password: password,
    bridgeCall: bridgeCall,
    autoSubmit: autoSubmit,
    enableTrustOption: enableTrustOption,
  );
}
