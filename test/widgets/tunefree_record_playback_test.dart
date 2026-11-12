import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:md3music/data/models/song.dart';
import 'package:md3music/widgets/record_sleeve_texture.dart';
import 'package:md3music/widgets/tunefree_record_rack.dart';

final _tracks = List.generate(
  20,
  (i) => Song(
    id: 'song-$i',
    title: 'Track $i',
    artist: 'Artist',
    album: 'Album',
    duration: const Duration(minutes: 3),
  ),
);

Future<void> _show(
  WidgetTester tester, {
  String? current = 'song-0',
  bool playing = true,
  bool ticker = true,
  bool reduced = false,
  List<Song>? tracks,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          disableAnimations: reduced,
        ),
        child: TickerMode(
          enabled: ticker,
          child: Scaffold(
            body: TuneFreeRecordRack(
              songs: tracks ?? _tracks,
              currentSongId: current,
              isPlaying: playing,
              onPlay: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

List<RotationTransition> _labels(WidgetTester tester, int number) {
  final sleeves = find.byWidgetPredicate(
    (w) => w is RecordSleeveTexture && w.number == number,
  );
  return tester
      .widgetList<RotationTransition>(
        find.descendant(of: sleeves, matching: find.byType(RotationTransition)),
      )
      .toList();
}

double _angle(WidgetTester tester, int number) =>
    _labels(tester, number).first.turns.value;

void main() {
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAllTestValues(),
  );
  testWidgets(
    'only the playing record rotates; pause and resume preserve angle',
    (tester) async {
      addTearDown(tester.view.reset);
      await _show(tester);
      final sleeve = find.byWidgetPredicate(
        (w) => w is RecordSleeveTexture && w.number == 1,
      );
      final bounds = tester.getRect(sleeve);
      final texture = find.descendant(of: sleeve, matching: find.byType(Image));
      expect(
        find.ancestor(of: texture, matching: find.byType(RotationTransition)),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(_angle(tester, 1), closeTo(3 / 22, .001));
      expect(_angle(tester, 2), 0);
      expect(tester.getRect(sleeve), bounds);
      await _show(tester, playing: false);
      final paused = _angle(tester, 1);
      await tester.pump(const Duration(seconds: 4));
      expect(_angle(tester, 1), paused);
      await _show(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(_angle(tester, 1), closeTo(paused + 2 / 22, .001));
      // Playback can change while the browsing selection stays on the first song.
      await _show(tester, current: 'song-1');
      await tester.pump(const Duration(seconds: 2));
      expect(_angle(tester, 1), 0);
      expect(_angle(tester, 2), closeTo(2 / 22, .001));
      expect(find.text('1 / 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );

  testWidgets('hidden, background and reduced-motion racks suspend rotation', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await _show(tester);
    await tester.pump(const Duration(seconds: 1));
    await _show(tester, ticker: false);
    var paused = _angle(tester, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(_angle(tester, 1), paused);
    await _show(tester, reduced: true);
    await tester.pump(const Duration(seconds: 3));
    expect(_angle(tester, 1), paused);
    await _show(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(_angle(tester, 1), greaterThan(paused));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    paused = _angle(tester, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(_angle(tester, 1), paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_angle(tester, 1), greaterThan(paused));
  });

  testWidgets(
    'off-rack playback does not tick and returning keeps the saved angle',
    (tester) async {
      addTearDown(tester.view.reset);
      await _show(tester);
      await tester.pump(const Duration(seconds: 1));
      final clock = _labels(tester, 1).first.turns as AnimationController;
      final region = find.byKey(const ValueKey('tunefree-rack-scroll-region'));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(region),
          scrollDelta: const Offset(0, 400),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(clock.isAnimating, isFalse);
      final paused = clock.value;
      await tester.pump(const Duration(seconds: 3));
      expect(clock.value, paused);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(region),
          scrollDelta: const Offset(0, -400),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('1 / 20'), findsOneWidget);
      expect(clock.isAnimating, isTrue);
      expect(_angle(tester, 1), greaterThan(paused));
      await _show(tester, current: 'not-in-favorites');
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets('looped copies share the playing song clock', (tester) async {
    addTearDown(tester.view.reset);
    await _show(tester, tracks: _tracks.take(2).toList());
    await tester.pump(const Duration(seconds: 2));
    final copies = _labels(tester, 2);
    expect(copies.length, 2);
    expect(copies.every((r) => r.turns.value == 0), isTrue);
    await _show(tester, tracks: _tracks.take(2).toList(), current: 'song-1');
    await tester.pump(const Duration(seconds: 2));
    final playingCopies = _labels(tester, 2);
    expect(
      identical(playingCopies.first.turns, playingCopies.last.turns),
      isTrue,
    );
    expect(playingCopies.first.turns.value, greaterThan(0));
  });
}
