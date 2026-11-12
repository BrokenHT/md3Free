import 'dart:collection';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// Explicit texture caching for decorations that move through a perspective
/// transform. Flutter's automatic raster cache may skip perspective layers.
/// Each mounted widget owns a clone; evicting a shared entry cannot invalidate
/// an image still on screen. Textures stay in memory and are never saved to disk.
class RasterizedDecoration extends StatefulWidget {
  const RasterizedDecoration({
    super.key,
    required this.painter,
    required this.cacheTag,
  });
  final CustomPainter painter;
  final String cacheTag;

  @override
  State<RasterizedDecoration> createState() => _RasterizedDecorationState();
}

final _textures = LinkedHashMap<String, ui.Image>();
final _pendingTextures = <String, Future<ui.Image>>{};

Future<ui.Image> _texture(
  String key,
  CustomPainter painter,
  Size size,
  double dpr,
) async {
  final cached = _textures.remove(key);
  if (cached != null) {
    _textures[key] = cached;
    return cached.clone();
  }
  final pending = _pendingTextures[key];
  if (pending != null) return (await pending).clone();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(dpr);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  final future = picture.toImage(
    (size.width * dpr).ceil(),
    (size.height * dpr).ceil(),
  );
  _pendingTextures[key] = future;
  try {
    final value = await future;
    _textures[key] = value;
    int bytes() => _textures.values.fold(
      0,
      (sum, image) => sum + image.width * image.height * 4,
    );
    while (_textures.length > 24 ||
        (bytes() > 48 * 1024 * 1024 && _textures.length > 1)) {
      _textures.remove(_textures.keys.first)!.dispose();
    }
    return value.clone();
  } finally {
    _pendingTextures.remove(key);
    picture.dispose();
  }
}

class _RasterizedDecorationState extends State<RasterizedDecoration> {
  ui.Image? _image;
  String? _key;
  int _version = 0;

  void _load(Size size, double dpr) {
    final key = '${widget.cacheTag}:${size.width}:${size.height}:$dpr';
    if (_key == key) return;
    _key = key;
    final version = ++_version;
    _texture(key, widget.painter, size, dpr).then(
      (image) {
        if (!mounted || version != _version) {
          image.dispose();
          return;
        }
        final previous = _image;
        setState(() => _image = image);
        // The old image can still belong to the current composited frame.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => previous?.dispose(),
        );
      },
      onError: (Object _) {
        // A failed snapshot retains the normal painter and remains readable.
      },
    );
  }

  @override
  void dispose() {
    _version++;
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (!size.isFinite || size.isEmpty) {
        return CustomPaint(painter: widget.painter);
      }
      final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
      _load(size, dpr);
      return _image == null
          ? CustomPaint(painter: widget.painter)
          : RawImage(
              image: _image,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.low,
            );
    },
  );
}
