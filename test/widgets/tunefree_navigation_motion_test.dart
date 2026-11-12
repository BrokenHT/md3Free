import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:md3music/core/layout/main_surface_route.dart';
import 'package:md3music/core/theme/tunefree_theme.dart';
import 'package:md3music/modules/player/full_player_route.dart';
import 'package:md3music/providers/theme_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('desktop search and sidebar fade together without relayout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final nav = GlobalKey<NavigatorState>();
    final widths = <double>[];
    const mainKey = Key('main-surface');
    const searchKey = Key('search-surface');
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        onGenerateRoute: (_) => MainSurfaceRoute<void>(
          builder: (_) => LayoutBuilder(
            builder: (_, box) {
              widths.add(box.maxWidth);
              return const SizedBox.expand(key: mainKey);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = tester.getRect(find.byKey(mainKey));
    nav.currentState!.push(
      ShellOverlayRoute<void>(
        builder: (_) => const SizedBox.expand(key: searchKey),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    double opacity(Key key) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(key, skipOffstage: false),
                matching: find.byType(Opacity, skipOffstage: false),
              )
              .first,
        )
        .opacity;
    expect(opacity(mainKey), inExclusiveRange(0.0, 1.0));
    expect(opacity(searchKey) + opacity(mainKey), closeTo(1, .001));
    expect(tester.getRect(find.byKey(mainKey)), initial);
    expect(tester.getSize(find.byKey(searchKey)), initial.size);
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(opacity(mainKey), inExclusiveRange(0.0, 1.0));
    expect(opacity(searchKey) + opacity(mainKey), closeTo(1, .001));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(mainKey)), initial);
    expect(widths.toSet(), {1280.0});
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phone background stays still on both sides of player halfway point',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final nav = GlobalKey<NavigatorState>();
      const anchor = Key('stationary-anchor');
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          child: MaterialApp(
            navigatorKey: nav,
            onGenerateRoute: (_) => MainSurfaceRoute<void>(
              builder: (_) => const Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(key: anchor, width: 340, height: 64),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bounds = tester.getRect(find.byKey(anchor));
      final route = DraggablePlayerRoute<void>(
        builder: (_) => const SizedBox.expand(),
        dragOriginTop: 740,
        dragOriginBottom: 804,
        screenHeight: 844,
      );
      nav.currentState!.push(route);
      await tester.pump();
      route.controller.stop();
      for (final progress in [.1, .49, .51, .9, 1.0, .9, .51, .49, .1, 0.0]) {
        route.controller.value = progress;
        await tester.pump();
        await tester.pump();
        expect(
          tester.getRect(find.byKey(anchor, skipOffstage: false)),
          bounds,
          reason: 'Player progress $progress must not move its source scene',
        );
      }
      nav.currentState!.removeRoute(route);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(anchor)), bounds);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone navigation hides labels and centers all five touch targets',
    (tester) async {
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        var selected = -1;
        final icons = List.generate(5, (i) => Key('nav-icon-$i'));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: TuneFreeNavigationBar(
                height: 58,
                selectedIndex: 1,
                onDestinationSelected: (i) => selected = i,
                destinations: List.generate(
                  5,
                  (i) => NavigationDestination(
                    icon: Icon(Icons.home_outlined, key: icons[i]),
                    label: '页面 $i',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(
          bar.labelBehavior,
          NavigationDestinationLabelBehavior.alwaysHide,
        );
        expect(tester.getSize(find.byType(NavigationBar)).height, 48);
        final centers = icons
            .map((key) => tester.getCenter(find.byKey(key)))
            .toList();
        for (var i = 1; i < centers.length; i++) {
          expect(centers[i].dy, closeTo(centers.first.dy, .1));
          expect(
            centers[i].dx - centers[i - 1].dx,
            closeTo((width - 28) / 5, .1),
          );
        }
        await tester.tap(find.byKey(icons.last));
        expect(selected, 4);
        expect(tester.takeException(), isNull);
      }
      tester.view.reset();
    },
  );
}
