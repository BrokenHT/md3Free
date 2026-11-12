import 'package:material_ui/material_ui.dart';
import 'player_artwork_image.dart';

/// All records share one pre-rendered glass/vinyl PNG. Only the circular album
/// beneath its transparent label changes. Flipping never paints grooves or
/// glass gradients, and does not create new textures per song.
class RecordSleeveTexture extends StatelessWidget {
  const RecordSleeveTexture({
    super.key,
    this.artworkUri,
    this.localPath,
    this.number,
    this.turns = const AlwaysStoppedAnimation<double>(0),
  });
  final String? artworkUri;
  final String? localPath;
  final int? number;
  final Animation<double> turns;

  static const labelFraction = (260 - 14) * .56 / 260;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: FractionallySizedBox(
            widthFactor: labelFraction,
            heightFactor: labelFraction,
            child: RepaintBoundary(
              child: RotationTransition(
                turns: turns,
                child: RepaintBoundary(
                  child: ClipOval(
                    child: PlayerArtworkImage(
                      artworkUri: artworkUri,
                      fallbackFilePath: localPath,
                      isFill: true,
                      backgroundColor: const Color(0xFF496F69),
                      iconColor: const Color(0xFF96E2D0),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/images/record_sleeve_dark.png'
              : 'assets/images/record_sleeve_light.png',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          cacheWidth: 512,
        ),
        if (number != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, bounds) => Padding(
                padding: EdgeInsets.only(
                  left: bounds.maxWidth * .045,
                  top: bounds.maxHeight * .08,
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ExcludeSemantics(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        number!.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: bounds.maxWidth * .031,
                          letterSpacing: 1.2,
                          color: const Color(0xBBE7DEF1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
