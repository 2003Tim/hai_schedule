import 'package:hai_schedule/utils/schedule_login_autofill_script.dart';
import 'package:hai_schedule/utils/schedule_login_semester_scripts.dart';

class ScheduleLoginScriptBuilder {
  static const apiUrl = ScheduleLoginSemesterScripts.apiUrl;

  static String buildDetectSemesterScript(String bridgeCall) =>
      ScheduleLoginSemesterScripts.buildDetectSemesterScript(bridgeCall);

  static String buildFetchScheduleScript({
    required String bridgeCall,
    required String semester,
  }) => ScheduleLoginSemesterScripts.buildFetchScheduleScript(
    bridgeCall: bridgeCall,
    semester: semester,
  );

  static String buildSwitchSemesterScript({
    required String bridgeCall,
    required String semester,
  }) => ScheduleLoginSemesterScripts.buildSwitchSemesterScript(
    bridgeCall: bridgeCall,
    semester: semester,
  );

  static String buildFillCredentialScript({
    required String username,
    required String password,
    String? bridgeCall,
    bool autoSubmit = true,
  }) => ScheduleLoginAutofillScript.build(
    username: username,
    password: password,
    bridgeCall: bridgeCall,
    autoSubmit: autoSubmit,
  );
}
