import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/theme/tunefree_theme.dart';
import 'player_artwork_image.dart';
import 'spinning_album_cover.dart';
import 'rasterized_decoration.dart';

class TuneFreeRecordArtwork extends StatelessWidget {
  const TuneFreeRecordArtwork({
    super.key,
    this.artworkUri,
    this.fallbackFilePath,
    this.label,
    this.playing = false,
    this.songId,
  });
  final String? artworkUri;
  final String? fallbackFilePath;
  final Widget? label;
  final bool playing;
  final String? songId;

  @override
  Widget build(BuildContext context) => PlaybackRotation(
    playing: playing,
    contentId: songId,
    duration: const Duration(seconds: 22),
    child: AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: RasterizedDecoration(
              cacheTag: 'vinyl-v2',
              painter: VinylPainter(),
            ),
          ),
          Center(
            child: FractionallySizedBox(
              widthFactor: .56,
              heightFactor: .56,
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    label ??
                        PlayerArtworkImage(
                          artworkUri: artworkUri,
                          fallbackFilePath: fallbackFilePath,
                          isFill: true,
                          backgroundColor: const Color(0xFF496F69),
                          iconColor: TuneFreeColors.mint,
                        ),
                    const Center(
                      child: SizedBox(
                        width: 7,
                        height: 7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFBCB1C9),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class VinylPainter extends CustomPainter {
  const VinylPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 2;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFF141316),
            Color(0xFF252429),
            Color(0xFF121115),
            Color(0xFF111014),
            Color(0xFF242327),
            Color(0xFF141316),
          ],
          stops: [0, .17, .31, .55, .76, 1],
        ).createShader(bounds),
    );
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..color = Colors.white.withValues(alpha: .04);
    for (var r = radius * .59; r < radius * .98; r += 1.8) {
      canvas.drawCircle(center, r, groove);
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF45414B),
    );
    canvas.drawCircle(
      center,
      radius * .575,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black54,
    );
  }

  @override
  bool shouldRepaint(covariant VinylPainter oldDelegate) => false;
}
