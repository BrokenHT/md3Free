import 'package:material_ui/material_ui.dart';
import '../../modules/player/full_player_route.dart';

/// Desktop search occupies the root viewport. Its geometry stays fixed while
/// the previous surface (including its sidebar) fades on the same animation.
class ShellOverlayRoute<T> extends MaterialPageRoute<T> {
  ShellOverlayRoute({required super.builder, super.settings});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => true;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(child: child),
      builder: (_, content) {
        final p = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(18 * (1 - p), 0),
            child: content,
          ),
        );
      },
    );
  }
}

enum _Cover { normal, player, search }

/// Opening the player never moves/reparents the main scene at the halfway
/// point. In particular, its measured mini-player anchor remains stationary.
class MainSurfaceRoute<T> extends MaterialPageRoute<T> {
  MainSurfaceRoute({required super.builder});
  _Cover _cover = _Cover.normal;

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    // Keep the mode through the reverse animation; null is announced before
    // the outgoing route has actually finished painting.
    if (nextRoute != null) {
      _cover = nextRoute is DraggablePlayerRoute
          ? _Cover.player
          : nextRoute is ShellOverlayRoute
          ? _Cover.search
          : _Cover.normal;
    }
    super.didChangeNext(nextRoute);
    changedInternalState();
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    if (nextRoute is DraggablePlayerRoute) return false;
    if (nextRoute is ShellOverlayRoute) return true;
    return super.canTransitionTo(nextRoute);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (_cover == _Cover.player) return child;
    if (_cover == _Cover.search) {
      return AnimatedBuilder(
        animation: secondaryAnimation,
        child: RepaintBoundary(child: child),
        builder: (_, content) => Opacity(
          opacity: 1 - Curves.easeOutCubic.transform(secondaryAnimation.value),
          child: content,
        ),
      );
    }
    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
