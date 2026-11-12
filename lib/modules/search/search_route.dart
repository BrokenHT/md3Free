import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import '../../core/layout/main_surface_route.dart';
import '../../core/layout/adaptive_navigator.dart';
import '../../core/layout/responsive_layout.dart';
import '../../core/layout/glass_overlay_layout.dart';
import '../player/now_playing_bar.dart';
import 'search_page.dart';

void openSearchPage(BuildContext context, {String? initialQuery}) {
  final desktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  Widget page(BuildContext context) {
    final search = TwoPanePage(child: SearchPage(initialQuery: initialQuery));
    // The regular search page already supplies its player. The optional desktop
    // shell normally owns a separate NowPlayingBar, so supply it on this route.
    return desktop && isDesktopLayout(context)
        ? GlassOverlayLayout(child: search, footer: const NowPlayingBar())
        : search;
  }

  Navigator.of(context, rootNavigator: desktop).push(
    desktop
        ? ShellOverlayRoute<void>(builder: page)
        : MaterialPageRoute<void>(builder: page),
  );
}
