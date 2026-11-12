import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps scrollable content behind transparent chrome. The measured footer
/// height becomes content padding, so the final list item can still be reached.
class GlassOverlayLayout extends StatefulWidget {
  const GlassOverlayLayout({
    super.key,
    required this.child,
    required this.footer,
  });
  final Widget child, footer;
  @override
  State<GlassOverlayLayout> createState() => _GlassOverlayLayoutState();
}

class _GlassOverlayLayoutState extends State<GlassOverlayLayout> {
  double _height = 0;
  void _resize(double height) {
    if (mounted && (height - _height).abs() > .5)
      setState(() => _height = height);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                bottom: media.padding.bottom + _height,
              ),
            ),
            child: widget.child,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: media.padding.bottom),
            child: _FooterMeasure(onHeight: _resize, child: widget.footer),
          ),
        ),
      ],
    );
  }
}

class _FooterMeasure extends SingleChildRenderObjectWidget {
  const _FooterMeasure({required this.onHeight, required super.child});
  final ValueChanged<double> onHeight;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _FooterMeasureBox(onHeight);
  @override
  void updateRenderObject(BuildContext context, _FooterMeasureBox box) =>
      box.onHeight = onHeight;
}

class _FooterMeasureBox extends RenderProxyBox {
  _FooterMeasureBox(this.onHeight);
  ValueChanged<double> onHeight;
  double _reported = -1;
  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size.height) return;
    _reported = size.height;
    final height = size.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}
