import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual JSON import screen and entry points are removed', () {
    expect(File('lib/screens/import_screen.dart').existsSync(), isFalse);

    for (final path in <String>[
      'lib/screens/home_screen.dart',
      'lib/screens/sync_center_screen.dart',
      'lib/screens/windows_desktop_shell_screen.dart',
      'lib/widgets/home_empty_state.dart',
      'lib/widgets/home_screen_sections.dart',
      'lib/widgets/sync_center_sections.dart',
      'lib/widgets/windows_desktop_shell_sections.dart',
      'lib/services/schedule_provider.dart',
      'README.md',
    ]) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains('ImportScreen')), reason: path);
      expect(text, isNot(contains('import_screen.dart')), reason: path);
      expect(text, isNot(contains('importFromJson')), reason: path);
      expect(text, isNot(contains('manualImport')), reason: path);
      expect(text, isNot(contains('onManualImport')), reason: path);
      expect(text, isNot(contains('手动导入')), reason: path);
      expect(text, isNot(contains('手动粘贴导入')), reason: path);
    }
  });
}
