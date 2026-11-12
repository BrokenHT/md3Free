import 'package:material_ui/material_ui.dart';

/// A compact editorial wordmark; the application name remains one accessible
/// label while its two parts have different rhythm, size and baseline.
class Md3FreeWordmark extends StatelessWidget {
  const Md3FreeWordmark({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'md3Free',
    child: ExcludeSemantics(
      child: SizedBox(
        width: 152,
        height: 46,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 13,
              child: Text(
                'md3',
                style: TextStyle(
                  fontSize: 22,
                  height: 1,
                  letterSpacing: -.6,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .85),
                ),
              ),
            ),
            const Positioned(
              left: 48,
              top: 2,
              child: Text(
                'Free',
                style: TextStyle(
                  fontSize: 34,
                  height: 1,
                  letterSpacing: -1.2,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF96E2D0),
                ),
              ),
            ),
            const Positioned(
              left: 111,
              top: 38,
              child: SizedBox(
                width: 20,
                height: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFBBA5DC),
                    borderRadius: BorderRadius.all(Radius.circular(2)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
