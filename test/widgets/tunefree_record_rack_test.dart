import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:md3music/core/theme/app_theme.dart';
import 'package:md3music/data/models/song.dart';
import 'package:md3music/widgets/tunefree_record_rack.dart';
import 'package:md3music/widgets/m3e_pull_to_refresh_fixed.dart';

List<Song> songs(int count) => List.generate(
  count,
  (i) => Song(
    id: 'song-$i',
    title: 'Track $i',
    artist: 'Artist',
    album: 'Album',
    duration: const Duration(minutes: 3),
  ),
);

Future<void> showRack(
  WidgetTester tester,
  List<Song> tracks, {
  ValueChanged<int>? onPlay,
  double width = 390,
}) async {
  tester.view.reset();
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              TuneFreeRecordRack(songs: tracks, onPlay: onPlay ?? (_) {}),
              const SizedBox(height: 1600, child: Text('Outside rack')),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> wheel(WidgetTester tester, Offset position, double delta) async {
  await tester.sendEventToBinding(
    PointerScrollEvent(
      position: position,
      scrollDelta: Offset(0, delta),
      kind: PointerDeviceKind.mouse,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final count in [1, 125]) {
    testWidgets(
      'upward wheel over $count records never pulls the page refresh header',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var refreshes = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: M3EPullToRefreshIndicator(
                onRefresh: () async {
                  refreshes++;
                },
                child: ListView(
                  children: [
                    TuneFreeRecordRack(songs: songs(count), onPlay: (_) {}),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final area = find.byKey(const ValueKey('tunefree-rack-scroll-region'));
        final initialTop = tester.getTopLeft(area).dy;
        await wheel(tester, tester.getCenter(area), -40);
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('$count / $count'), findsOneWidget);
        expect(refreshes, 0);
        expect(tester.getTopLeft(area).dy, initialTop);
        // The same gesture outside the rack still belongs to page refresh.
        await wheel(tester, const Offset(100, 160), -300);
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        expect(refreshes, 1);
      },
    );
  }
  testWidgets('desktop side whitespace scrolls page, not the records', (
    tester,
  ) async {
    await showRack(tester, songs(125), width: 1280);
    final region = tester.getRect(
      find.byKey(const ValueKey('tunefree-rack-scroll-region')),
    );
    expect(region.width, lessThan(540));
    await wheel(tester, Offset(region.left - 30, region.center.dy), 120);
    expect(find.text('1 / 125'), findsOneWidget);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      greaterThan(0),
    );
  });
  testWidgets('wheel inside rack advances selection without scrolling parent', (
    tester,
  ) async {
    await showRack(tester, songs(5));
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    await wheel(
      tester,
      tester.getCenter(
        find.byKey(const ValueKey('tunefree-rack-scroll-region')),
      ),
      120,
    );
    expect(find.text('4 / 5'), findsOneWidget);
    expect(scroll.pixels, 0);
  });
  testWidgets(
    'wheel outside rack scrolls page and leaves selection unchanged',
    (tester) async {
      await showRack(tester, songs(5));
      await wheel(tester, const Offset(180, 700), 120);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        greaterThan(0),
      );
      expect(find.text('1 / 5'), findsOneWidget);
    },
  );
  testWidgets('looping previous selects the last actual song and plays it', (
    tester,
  ) async {
    int? played;
    await showRack(tester, songs(5), onPlay: (index) => played = index);
    await tester.tap(find.byTooltip('上一张唱片'));
    await tester.pumpAndSettle();
    expect(find.text('5 / 5'), findsOneWidget);
    await tester.tap(find.byTooltip('播放这张唱片'));
    await tester.pump();
    expect(played, 4);
  });
  testWidgets('touch drag changes selected record', (tester) async {
    await showRack(tester, songs(10));
    await tester.drag(
      find.byKey(const ValueKey('tunefree-rack-scroll-region')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 10'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid wheel events accumulate instead of being debounced away', (
    tester,
  ) async {
    await showRack(tester, songs(100));
    final point = tester.getCenter(
      find.byKey(const ValueKey('tunefree-rack-scroll-region')),
    );
    for (var i = 0; i < 8; i++) {
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: point,
          scrollDelta: const Offset(0, 120),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump(const Duration(milliseconds: 12));
    }
    await tester.pumpAndSettle();
    expect(find.text('25 / 100'), findsOneWidget);
    await wheel(tester, point, -240);
    expect(find.text('19 / 100'), findsOneWidget);
    expect(
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels,
      0,
    );
  });
  testWidgets(
    'last to first loops forward with directional caption and stable controls',
    (tester) async {
      await showRack(tester, songs(5));
      await tester.tap(find.byTooltip('上一张唱片'));
      await tester.pumpAndSettle();
      expect(find.text('5 / 5'), findsOneWidget);
      final controls = tester.getCenter(find.byTooltip('下一张唱片'));
      await tester.tap(find.byTooltip('下一张唱片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final nextMotion = tester.widget<Transform>(
        find.byKey(const ValueKey('rack-caption-motion')),
      );
      expect(nextMotion.transform.storage[13], lessThan(0));
      expect(
        tester
            .widget<Opacity>(find.byKey(const ValueKey('rack-caption-opacity')))
            .opacity,
        lessThan(1),
      );
      expect(tester.getCenter(find.byTooltip('下一张唱片')), controls);
      await tester.pumpAndSettle();
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text('Track 0'), findsOneWidget);
      await tester.tap(find.byTooltip('上一张唱片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final previousMotion = tester.widget<Transform>(
        find.byKey(const ValueKey('rack-caption-motion')),
      );
      expect(previousMotion.transform.storage[13], greaterThan(0));
      await tester.pumpAndSettle();
      expect(find.text('5 / 5'), findsOneWidget);
    },
  );
  testWidgets('selection survives favorites updates by song identity', (
    tester,
  ) async {
    final original = songs(5);
    await showRack(tester, original);
    await tester.tap(find.byTooltip('下一张唱片'));
    await tester.pumpAndSettle();
    await showRack(tester, original.reversed.toList());
    expect(find.text('Track 1'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
  });
  testWidgets(
    'empty, single, huge libraries and narrow screens do not overflow',
    (tester) async {
      for (final width in [320.0, 390.0, 1280.0]) {
        for (final count in [0, 1, 2, 1000]) {
          await showRack(tester, songs(count), width: width);
          expect(tester.takeException(), isNull, reason: '$width / $count');
          final sleeves = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('rack-sleeve-'),
          );
          expect(sleeves.evaluate().length, lessThanOrEqualTo(9));
        }
      }
    },
  );
  testWidgets('keyboard arrows are scoped to the focused rack', (tester) async {
    await showRack(tester, songs(4));
    await tester.tapAt(
      tester.getTopLeft(
            find.byKey(const ValueKey('tunefree-rack-scroll-region')),
          ) +
          const Offset(4, 4),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsOneWidget);
  });
}
