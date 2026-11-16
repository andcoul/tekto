// T077 — coach screen: streamed reply, inline "unavailable" message (never a spinner),
// remaining free questions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';

import 'coach_harness.dart';

void main() {
  testWidgets('the reply appears as it streams in', (tester) async {
    final h = CoachHarness();
    await h.pump(tester);

    await h.ask(tester, 'How long should I rest?');
    expect(find.text('How long should I rest?'), findsOneWidget);

    h.api.events.add(const SseEvent('text', {'text': 'Rest 2'}));
    await tester.pump();
    expect(find.text('Rest 2'), findsOneWidget);

    h.api.events
      ..add(const SseEvent('text', {'text': ' minutes.'}))
      ..add(const SseEvent('done', {'message_id': 'srv-1', 'plan_change_proposed': null, 'quota_remaining': 2}));
    await h.api.events.close();
    await tester.pumpAndSettle();

    expect(find.text('Rest 2 minutes.'), findsOneWidget);
    expect(find.text('2 questions left this week'), findsOneWidget);
  });

  testWidgets('no spinner while waiting for the first words', (tester) async {
    final h = CoachHarness();
    await h.pump(tester);
    await h.ask(tester, 'Hi');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await h.api.events.close();
    await tester.pumpAndSettle();
  });

  testWidgets('AI_UNAVAILABLE shows the inline message, never a spinner, and keeps the question', (tester) async {
    final h = CoachHarness()..api.error = const ApiStatusException(503, 'AI_UNAVAILABLE');
    await h.pump(tester);

    await h.ask(tester, 'Explain RPE');
    await tester.pumpAndSettle();

    expect(find.text('The coach is temporarily unavailable. Your plan still works — try again in a moment.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Explain RPE'), findsOneWidget); // the user's bubble stays
  });

  testWidgets('a reply that fails mid-stream is replaced by the inline message', (tester) async {
    final h = CoachHarness();
    await h.pump(tester);

    await h.ask(tester, 'Explain RPE');
    h.api.events
      ..add(const SseEvent('text', {'text': 'RPE is a'}))
      ..add(const SseEvent('error', {'error': 'AI_UNAVAILABLE'}));
    await h.api.events.close();
    await tester.pumpAndSettle();

    expect(find.text('RPE is a'), findsNothing);
    expect(find.text('The coach is temporarily unavailable. Your plan still works — try again in a moment.'), findsOneWidget);
  });

  testWidgets('free users see their remaining questions from the start', (tester) async {
    await CoachHarness().pump(tester);
    expect(find.text('3 questions left this week'), findsOneWidget);
  });

  testWidgets('Pro users see no question count', (tester) async {
    await CoachHarness().pump(tester, pro: true);
    expect(find.textContaining('questions left this week'), findsNothing);
  });

  testWidgets('French strings', (tester) async {
    final h = CoachHarness();
    await h.pump(tester, locale: const Locale('fr'));
    expect(find.text('Ask your coach…'), findsNothing);
  });
}
