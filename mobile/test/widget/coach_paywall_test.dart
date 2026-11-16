// T116 — coach paywall surface (Constitution V), written before the T077 screen update.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/subscription/ui/paywall_screen.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';

import 'coach_harness.dart';

void main() {
  testWidgets("free user's 4th question during a workout: paywall bottom sheet, workout still usable", (tester) async {
    final h = CoachHarness()..api.error = const ApiStatusException(429, 'QUOTA_EXCEEDED');
    await h.pump(tester, workoutActive: true);

    await h.ask(tester, 'Can I train legs today?');
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(PaywallView)), findsOneWidget);
    expect(find.text('WORKOUT SCREEN'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Cancel anytime'), findsOneWidget);
    expect(h.fullScreenPaywalls, isEmpty);

    // "Continue workout" closes the sheet; the typed question is still there to re-send.
    await tester.tap(find.text('Continue workout'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Can I train legs today?');
  });

  testWidgets('free user outside a workout: the full coach paywall opens', (tester) async {
    final h = CoachHarness()..api.error = const ApiStatusException(429, 'QUOTA_EXCEEDED');
    await h.pump(tester);

    await h.ask(tester, 'One more question');
    await tester.pumpAndSettle();

    expect(h.fullScreenPaywalls, [PaywallFeature.coach]);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'One more question');
  });

  testWidgets('the unanswered question is not left in the conversation', (tester) async {
    final h = CoachHarness()..api.error = const ApiStatusException(429, 'QUOTA_EXCEEDED');
    await h.pump(tester);

    await h.ask(tester, 'Unanswered?');
    await tester.pumpAndSettle();

    // Only in the input field, not as a sent bubble.
    expect(find.text('Unanswered?'), findsOneWidget);
    expect(find.descendant(of: find.byType(TextField), matching: find.text('Unanswered?')), findsOneWidget);
  });
}
