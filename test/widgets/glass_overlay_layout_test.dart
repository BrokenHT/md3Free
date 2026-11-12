import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:md3music/core/layout/glass_overlay_layout.dart';

void main() {
  testWidgets('content continues behind glass and the last row clears both bars', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    double? inset;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MediaQuery(
      data: const MediaQueryData(padding: EdgeInsets.only(bottom: 64)),
      child: GlassOverlayLayout(
        footer: const SizedBox(key: ValueKey('footer'), height: 68, width: double.infinity),
        child: Builder(builder: (context) {
          inset = MediaQuery.paddingOf(context).bottom;
          return ListView.builder(
            padding: EdgeInsets.only(bottom: inset!), itemCount: 30, itemExtent: 50,
            itemBuilder: (_, i) => Text('row $i'),
          );
        }),
      ),
    ))));
    await tester.pumpAndSettle();
    expect(inset, 132);
    expect(tester.getRect(find.byType(ListView)).height, 800);
    expect(tester.getRect(find.byKey(const ValueKey('footer'))).bottom, 736);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('row 29')).bottom, lessThanOrEqualTo(668));
    expect(tester.takeException(), isNull);
  });
}
