import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:md3music/widgets/spinning_album_cover.dart';
import 'package:md3music/widgets/scroll_aware_app_bar.dart';

void main() {
  testWidgets('album rotates only while playing and resumes its saved angle', (
    tester,
  ) async {
    Future<void> show(bool playing, {bool reduced = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: SpinningAlbumCover(
              playing: playing,
              size: 44,
              songId: 'test',
            ),
          ),
        ),
      );
    }

    double angle() => tester
        .widget<RotationTransition>(find.byType(RotationTransition))
        .turns
        .value;
    await show(true);
    await tester.pump(const Duration(seconds: 3));
    expect(angle(), greaterThan(0));
    await show(false);
    final paused = angle();
    await tester.pump(const Duration(seconds: 2));
    expect(angle(), paused);
    await show(true);
    await tester.pump(const Duration(seconds: 1));
    expect(angle(), greaterThan(paused));
    await show(true, reduced: true);
    final still = angle();
    await tester.pump(const Duration(seconds: 2));
    expect(angle(), still);
    expect(find.byType(ClipOval), findsOneWidget);
  });

  testWidgets('scrolling never paints a black title rectangle', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: ScrollAwareAppBar(
            title: 'md3Free',
            scrollController: controller,
          ),
          body: ListView(
            controller: controller,
            children: const [SizedBox(height: 2500)],
          ),
        ),
      ),
    );
    controller.jumpTo(600);
    await tester.pump();
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.backgroundColor, Colors.transparent);
    expect(bar.scrolledUnderElevation, 0);
  });
}
