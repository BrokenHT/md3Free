import 'dart:ui';
import 'dart:math' as math;
import '../services/frame_timing_probe.dart';
import '../../widgets/rasterized_decoration.dart';

import 'package:material_ui/material_ui.dart';

/// Shared with the accepted TuneFree Android design (liquid.css).
abstract final class TuneFreeColors {
  static const background = Color(0xFF110D20);
  static const panel = Color(0xFF241C35);
  static const ink = Color(0xFFF6F1FF);
  static const muted = Color(0xFFC7BAD9);
  static const mint = Color(0xFF96E2D0);

  static ColorScheme scheme(ColorScheme base, {bool useDefaultAccent = true}) {
    final dark = base.brightness == Brightness.dark;
    return base.copyWith(
      primary: useDefaultAccent
          ? (dark ? mint : const Color(0xFF247C70))
          : base.primary,
      onPrimary: useDefaultAccent
          ? (dark ? const Color(0xFF132B28) : Colors.white)
          : base.onPrimary,
      primaryContainer: useDefaultAccent
          ? (dark ? const Color(0xFF314B4A) : const Color(0xFFCBEFE6))
          : base.primaryContainer,
      onPrimaryContainer: useDefaultAccent
          ? (dark ? mint : const Color(0xFF164D44))
          : base.onPrimaryContainer,
      secondary: dark ? const Color(0xFFCFB9F4) : const Color(0xFF6D508D),
      secondaryContainer: dark
          ? const Color(0xFF473655)
          : const Color(0xFFE3D7F3),
      onSecondaryContainer: dark ? mint : const Color(0xFF49315F),
      surface: dark ? background : const Color(0xFFECE5F8),
      onSurface: dark ? ink : const Color(0xFF231B36),
      onSurfaceVariant: dark ? muted : const Color(0xFF63566F),
      surfaceContainerLowest: dark
          ? const Color(0xFF100B1C)
          : const Color(0xFFFDFBFF),
      surfaceContainerLow: dark
          ? const Color(0xFF1C162B)
          : const Color(0xFFF7F1FE),
      surfaceContainer: dark ? panel : const Color(0xFFFBF7FF),
      surfaceContainerHigh: dark
          ? const Color(0xFF302641)
          : const Color(0xFFE9DFF4),
      surfaceContainerHighest: dark
          ? const Color(0xFF3D304F)
          : const Color(0xFFDED0ED),
      outline: dark ? const Color(0xFF8D7C9F) : const Color(0xFF8C7B9C),
      outlineVariant: dark ? const Color(0xFF443650) : const Color(0xFFD5C6E4),
      surfaceTint: Colors.transparent,
    );
  }
}

class TuneFreeAtmosphere extends StatelessWidget {
  const TuneFreeAtmosphere({super.key});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RasterizedDecoration(
      cacheTag: 'atmosphere:${Theme.of(context).brightness}',
      painter: _AtmospherePainter(
        Theme.of(context).brightness == Brightness.dark,
      ),
    ),
  );
}

void _ellipse(Canvas canvas, Offset center, double rx, double ry, Color color) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(rx, ry);
  const unit = Rect.fromLTWH(-1, -1, 2, 2);
  canvas.drawOval(
    unit,
    Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0, 1],
      ).createShader(unit),
  );
  canvas.restore();
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(
      dark ? TuneFreeColors.background : const Color(0xFFF3EDF9),
      BlendMode.src,
    );
    _ellipse(
      canvas,
      const Offset(0, 0),
      size.width * .96,
      size.height * .85,
      dark ? const Color(0xFF3E2B60) : const Color(0xFFE2D5F3),
    );
    _ellipse(
      canvas,
      Offset(0, size.height),
      math.min(340, size.width * .65),
      210,
      const Color(0x5967C4C9).withValues(alpha: dark ? .35 : .16),
    );
    _ellipse(
      canvas,
      Offset(size.width, size.height),
      math.min(440, size.width * .83),
      220,
      const Color(0x65B38CEC).withValues(alpha: dark ? .40 : .18),
    );
  }

  @override
  bool shouldRepaint(covariant _AtmospherePainter old) => dark != old.dark;
}

/// Port of TuneFree liquid.css: one soft specular rim, elliptical highlights,
/// low-opacity lavender fill, and a bounded backdrop sample. Acrylic sleeves
/// have their own reflection sheet and never blur every record separately.
class TuneFreeGlass extends StatelessWidget {
  const TuneFreeGlass({
    super.key,
    required this.child,
    this.radius = 28,
    this.blur = true,
    this.sleeve = false,
  });
  final Widget child;
  final double radius;
  final bool blur, sleeve;

  @override
  Widget build(BuildContext context) {
    final enabled = blur && !MediaQuery.disableAnimationsOf(context);
    if (frameProbeEnabled) {
      return ValueListenableBuilder<bool>(
        valueListenable: frameProbeBlur,
        builder: (_, value, _) => _build(context, enabled && value),
      );
    }
    return _build(context, enabled);
  }

  Widget _build(BuildContext context, bool blurEnabled) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: ClipRect(
                  child: blurEnabled
                      ? BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                          child: ColoredBox(
                            color: dark
                                ? const Color(0x30302044)
                                : const Color(0xBBF6F0FF),
                          ),
                        )
                      : ColoredBox(
                          color: dark
                              ? const Color(0x20302044)
                              : const Color(0xBBF6F0FF),
                        ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: RasterizedDecoration(
                  cacheTag: 'glass:$radius:$dark:$sleeve:base',
                  painter: LiquidGlassPainter(radius, dark, sleeve, false),
                ),
              ),
            ),
          ),
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: RasterizedDecoration(
                  cacheTag: 'glass:$radius:$dark:$sleeve:rim',
                  painter: LiquidGlassPainter(radius, dark, sleeve, true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiquidGlassPainter extends CustomPainter {
  const LiquidGlassPainter(this.radius, this.dark, this.sleeve, this.rim);
  final double radius;
  final bool dark, sleeve, rim;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final actualRadius = math.min(
      radius,
      math.min(size.width, size.height) / 2,
    );
    final shape = RRect.fromRectAndRadius(
      rect.deflate(.65),
      Radius.circular(actualRadius),
    );
    if (!rim) {
      canvas.drawRRect(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: sleeve
                ? const [
                    Color(0x38F2EAFD),
                    Color(0x08F5EBFF),
                    Color(0x21C2B3DF),
                    Color(0x22FFFFFF),
                  ]
                : const [
                    Color(0x16E8DCFF),
                    Color(0x02FFFFFF),
                    Color(0x07D9CAFF),
                    Color(0x1996E2D0),
                  ],
            stops: sleeve ? const [0, .38, .68, 1] : const [0, .42, .63, 1],
          ).createShader(rect),
      );
      if (sleeve) {
        // These reflections belong to the clear case behind the vinyl. Painting
        // them over the record washes its black grooves into a grey disc.
        _ellipse(
          canvas,
          Offset.zero,
          size.width * .38,
          size.height * .38,
          const Color(0x88FFFFFF),
        );
        _ellipse(
          canvas,
          Offset(size.width * .98, size.height * .95),
          size.width * .4,
          size.height * .4,
          const Color(0x4DE2D9F9),
        );
      }
      return;
    }
    canvas.save();
    canvas.clipRRect(shape);
    if (sleeve) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment(-1, -.8),
            end: Alignment(1, .8),
            colors: [
              Color(0x22FFFFFF),
              Colors.transparent,
              Colors.transparent,
              Color(0x13FFFFFF),
              Colors.transparent,
            ],
            stops: [0, .23, .7, .85, 1],
          ).createShader(rect),
      );
    } else {
      // CSS ellipses use independent radii. A circular radial gradient across
      // the entire capsule makes a tall sidebar look flat and over-bright.
      _ellipse(
        canvas,
        Offset(size.width * .22, 0),
        math.min(160, size.width * .8),
        75,
        const Color(0x2DF6F2FF),
      );
      _ellipse(
        canvas,
        Offset(size.width * .22, 2),
        math.min(115, size.width * .65),
        20,
        const Color(0x26FFFFFF),
      );
      _ellipse(
        canvas,
        Offset(size.width * .80, size.height - 2),
        math.min(125, size.width * .65),
        15,
        const Color(0x1AC7ECEB),
      );
    }
    // A soft bevel immediately inside the rim, not a second outlined shape.
    final bevel = RRect.fromRectAndRadius(
      rect.deflate(1.25),
      Radius.circular(math.max(0, actualRadius - .6)),
    );
    canvas.drawRRect(
      bevel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sleeve ? 3.0 : 2.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: sleeve
              ? const [
                  Color(0xA0FFFFFF),
                  Color(0x18FFFFFF),
                  Color(0x18FFFFFF),
                  Color(0x70E8DAFA),
                ]
              : const [
                  Color(0x35FFFFFF),
                  Color(0x03FFFFFF),
                  Color(0x01FFFFFF),
                  Color(0x29B7F4ED),
                ],
          stops: [0, .2, .8, 1],
        ).createShader(rect),
    );
    canvas.restore();
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sleeve ? 1.25 : 1.1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: sleeve
              ? const [
                  Color(0xD0FFFFFF),
                  Color(0x8CE9DCFF),
                  Color(0x80FFFFFF),
                  Color(0xA0CAE8F4),
                  Color(0x90EFE5FF),
                  Color(0xB0FFFFFF),
                ]
              : const [
                  Color(0xADFFFFFF),
                  Color(0x14E9DCFF),
                  Color(0x03FFFFFF),
                  Color(0x6BCAE8F4),
                  Color(0x22EFE5FF),
                  Color(0x66FFFFFF),
                ],
          stops: [0, .29, .48, .74, .89, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant LiquidGlassPainter old) =>
      radius != old.radius ||
      dark != old.dark ||
      sleeve != old.sleeve ||
      rim != old.rim;
}

class TuneFreeNavigationBar extends StatelessWidget {
  const TuneFreeNavigationBar({
    super.key,
    required this.height,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });
  final double height;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> destinations;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 3, 14, 7),
      child: TuneFreeGlass(
        radius: 999,
        child: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: NavigationBar(
            height: height - 10,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            backgroundColor: Colors.transparent,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: destinations,
          ),
        ),
      ),
    ),
  );
}
