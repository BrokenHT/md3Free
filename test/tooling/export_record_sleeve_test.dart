import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:md3music/core/theme/tunefree_theme.dart';
import 'package:md3music/widgets/tunefree_record_artwork.dart';

/// Reproducible source for the shared PNGs. Only run this when changing the
/// material; the app ships the images and never runs this drawing sequence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export static TuneFree glass record sleeves', () async {
    const size = Size.square(260);
    for (final dark in [true, false]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(1024 / 260);
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      );
      canvas.drawColor(
        dark ? const Color(0x20302044) : const Color(0xBBF6F0FF),
        BlendMode.src,
      );
      LiquidGlassPainter(20, dark, true, false).paint(canvas, size);
      canvas.save();
      canvas.translate(7, 7);
      const VinylPainter().paint(canvas, const Size.square(246));
      canvas.restore();
      canvas.drawCircle(
        const Offset(130, 130),
        246 * .28,
        Paint()..blendMode = BlendMode.clear,
      );
      LiquidGlassPainter(20, dark, true, true).paint(canvas, size);
      canvas.drawCircle(
        const Offset(130, 130),
        3.5,
        Paint()..color = const Color(0xFFBCB1C9),
      );
      canvas.drawCircle(
        const Offset(130, 130),
        3.5,
        Paint()
          ..color = const Color(0x55FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
      canvas.restore();
      final picture = recorder.endRecording();
      final image = await picture.toImage(1024, 1024);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'assets/images/record_sleeve_${dark ? 'dark' : 'light'}.png',
      ).writeAsBytes(
        data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      image.dispose();
      picture.dispose();
    }
  }, skip: Platform.environment['MD3FREE_EXPORT_RECORD_TEXTURES'] != '1');
}
