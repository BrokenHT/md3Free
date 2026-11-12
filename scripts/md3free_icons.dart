import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final master = img.decodePng(File('assets/images/app_icon.png').readAsBytesSync())!.convert(numChannels: 4);
  final square = img.copyResize(master, width: 512, height: 512, interpolation: img.Interpolation.cubic);
  final rounded = img.copyCrop(square, x: 0, y: 0, width: 512, height: 512, radius: 112);
  void save(String path, img.Image image) => File(path).writeAsBytesSync(img.encodePng(image));
  save('android/app/src/main/res/mipmap-nodpi/ic_launcher.png', rounded);
  save('android/app/src/main/res/drawable-nodpi/ic_launcher_legacy_cropped.png', rounded);
  save('android/app/src/main/res/drawable/ic_launcher_foreground.png', square);
  final background = img.Image(width: 16, height: 16, numChannels: 4);
  img.fill(background, color: img.ColorRgba8(17, 13, 32, 255));
  save('android/app/src/main/res/drawable/ic_launcher_background.png', background);
  final monochrome = img.Image(width: 512, height: 512, numChannels: 4);
  for (final pixel in square) {
    final light = [pixel.r, pixel.g, pixel.b].reduce((a,b) => a > b ? a : b);
    final alpha = ((light - 45) / 75 * 255).clamp(0, 255).round();
    monochrome.setPixelRgba(pixel.x, pixel.y, 255, 255, 255, alpha);
  }
  save('android/app/src/main/res/drawable/ic_launcher_monochrome.png', monochrome);
  save('android/app/src/main/res/drawable/ic_launcher_monochrome_classic.png', monochrome);
  File('assets/images/app_icon_3.jpg').writeAsBytesSync(img.encodeJpg(square, quality: 94));
  final frames = [16, 24, 32, 48, 64, 128, 256].map((n) => img.copyResize(rounded,
    width: n, height: n, interpolation: img.Interpolation.cubic)).toList();
  File('windows/runner/resources/app_icon.ico').writeAsBytesSync(img.IcoEncoder().encodeImages(frames));
  print('Generated platform icon sizes from the approved md3Free master.');
}
