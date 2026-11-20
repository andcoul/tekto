// The caption over bundled clips (welcome, paywall). Flutter's ClosedCaption always pins
// itself to the bottom of its space, which hid the welcome caption under the screen's fade.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/widgets/bundled_clip.dart';

Future<void> pump(WidgetTester tester, String text) => tester.pumpWidget(MaterialApp(
      home: Stack(fit: StackFit.expand, children: [
        Align(alignment: const Alignment(0, -0.72), child: ClipCaption(text: text)),
      ]),
    ));

void main() {
  testWidgets('shows the cue text where it is placed, not at the bottom', (tester) async {
    await pump(tester, 'Train with a coach that adapts to you.');
    final box = tester.getRect(find.text('Train with a coach that adapts to you.'));
    final screen = tester.getSize(find.byType(Stack));
    expect(box.center.dy, lessThan(screen.height / 2));
  });

  testWidgets('shows nothing between cues', (tester) async {
    await pump(tester, '');
    expect(find.byType(Text), findsNothing);
  });
}
