import 'package:material_ui/material_ui.dart';

import 'smart_artwork_image.dart';

/// Only this small transform ticks. Pause retains the angle; hidden pages and
/// reduced-motion mode stop the ticker. The decoded artwork is a cached layer.
class SpinningAlbumCover extends StatelessWidget {
  const SpinningAlbumCover({
    super.key,
    required this.playing,
    required this.size,
    this.songId,
    this.artworkUri,
    this.fallbackFilePath,
  });
  final bool playing;
  final double size;
  final String? songId, artworkUri, fallbackFilePath;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: PlaybackRotation(
      playing: playing,
      contentId: songId,
      child: ClipOval(
        child: SmartArtworkImage(
          artworkUri: artworkUri,
          fallbackFilePath: fallbackFilePath,
          songId: songId,
          size: size,
          borderRadius: size / 2,
        ),
      ),
    ),
  );
}

/// Shared by the small album and the full-size vinyl. Keeps the angle through
/// pause/resume, and suspends hidden/background/reduced-motion animations.
class PlaybackRotation extends StatefulWidget {
  const PlaybackRotation({
    super.key,
    required this.playing,
    required this.child,
    this.contentId,
    this.duration = const Duration(seconds: 14),
  });
  final bool playing;
  final Widget child;
  final String? contentId;
  final Duration duration;
  @override
  State<PlaybackRotation> createState() => _PlaybackRotationState();
}

class _PlaybackRotationState extends State<PlaybackRotation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _turn = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _sync() {
    final active =
        widget.playing &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (active && !_turn.isAnimating) _turn.repeat();
    if (!active && _turn.isAnimating) _turn.stop(canceled: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PlaybackRotation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentId != widget.contentId) _turn.value = 0;
    _turn.duration = widget.duration;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (mounted) _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: RotationTransition(
      turns: _turn,
      child: RepaintBoundary(child: widget.child),
    ),
  );
}
