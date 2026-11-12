import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:md3music/core/services/desktop_lyric_service.dart';
import 'package:md3music/modules/settings/desktop_lyric_settings_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    fakeAsync((_) {
      DesktopLyricService.instance;
    });
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('紧凑胶囊预览在窄屏不溢出（缩放 $scale）', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SingleChildScrollView(child: DesktopLyricSettingsPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final preview = tester.getRect(
        find.byKey(const ValueKey('lyric-capsule-preview')),
      );
      expect(preview.height, 68);
      expect(preview.width, lessThanOrEqualTo(288));
      expect(find.text('双行'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
