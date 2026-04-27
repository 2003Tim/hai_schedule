import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android launch resources', () {
    test(
      'uses layered launch background with fallback color and centered logo',
      () {
        final xml =
            File(
              'android/app/src/main/res/drawable/launch_background.xml',
            ).readAsStringSync();

        expect(xml, contains('@color/splash_bg_color'));
        expect(xml, contains('android:src="@drawable/background"'));
        expect(xml, contains('android:gravity="fill"'));
        expect(
          xml,
          contains('android:drawable="@drawable/android12splash_safe"'),
        );
        expect(xml, contains('android:gravity="center"'));
      },
    );

    test('has tablet landscape launch background override', () {
      final file = File(
        'android/app/src/main/res/drawable-sw600dp-land/launch_background.xml',
      );
      final background = File(
        'android/app/src/main/res/drawable-sw600dp-land/background.png',
      );
      expect(file.existsSync(), isTrue);
      expect(background.existsSync(), isTrue);

      final xml = file.readAsStringSync();
      expect(xml, contains('@color/splash_bg_color'));
      expect(xml, contains('android:src="@drawable/background"'));
      expect(xml, contains('android:gravity="fill"'));
    });

    test('defines splash color and transparent system bars', () {
      final colors =
          File('android/app/src/main/res/values/colors.xml').readAsStringSync();
      final styles =
          File(
            'android/app/src/main/res/values-v31/styles.xml',
          ).readAsStringSync();
      final main = File('lib/main.dart').readAsStringSync();

      expect(colors, contains('name="splash_bg_color"'));
      expect(styles, contains('@color/splash_bg_color'));
      expect(styles, contains('android:statusBarColor'));
      expect(styles, contains('@android:color/transparent'));
      expect(main, contains('SystemUiMode.edgeToEdge'));
      expect(main, contains('systemNavigationBarColor: Colors.transparent'));
    });
  });
}
