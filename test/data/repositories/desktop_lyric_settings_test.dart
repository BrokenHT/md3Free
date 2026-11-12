import 'package:flutter_test/flutter_test.dart';
import 'package:md3music/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy karaoke font sizes migrate into the compact capsule range',
    () async {
      final repository = SettingsRepository();
      for (final entry in {
        40.0: 16.0,
        100.0: 18.0,
        10.0: 12.0,
        15.0: 15.0,
      }.entries) {
        SharedPreferences.setMockInitialValues({
          'settings_dl_font_size': entry.key,
        });
        expect(await repository.getDesktopLyricFontSize(), entry.value);
      }
    },
  );

  group('SettingsRepository desktop lyric horizontal movement', () {
    test('未保存时默认允许左右移动', () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await SettingsRepository().getDesktopLyricAllowHorizontalMove(),
        isTrue,
      );
    });

    test('开关关闭后可持久化读回', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = SettingsRepository();
      await repo.setDesktopLyricAllowHorizontalMove(false);
      expect(await repo.getDesktopLyricAllowHorizontalMove(), isFalse);
    });
  });
}
