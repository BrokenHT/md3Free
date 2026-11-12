import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../data/models/song.dart';
import '../../widgets/player_artwork_image.dart';
import '../utils/local_media_path.dart';
import 'local_artwork_cache.dart';

/// Small PNG shared by the two native capsule renderers. Embedded covers are
/// decoded to 128 px before crossing the channel, never sent at camera size.
Future<Uint8List?> floatingLyricArtwork(Song song) async {
  ui.Image? owned;
  try {
    final online = await resolvePlayerArtworkImage(
      artworkUri: song.artworkUri,
      settledLogicalWidth: 128,
      devicePixelRatio: 1,
    );
    ui.Image? image = online;
    if (image == null) {
      final uri = song.artworkUri;
      final path = normalizeLocalMediaPath(
        uri != null && uri.startsWith('local://')
            ? uri.substring(8)
            : song.localPath,
      );
      if (path == null) return null;
      final bytes = await LocalArtworkCache().getArtwork(path);
      if (bytes == null) return null;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 128);
      try {
        owned = (await codec.getNextFrame()).image;
        image = owned;
      } finally {
        codec.dispose();
      }
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (_) {
    return null;
  } finally {
    owned?.dispose();
  }
}
