// T086 — the adaptation card on the plan and the summary screen (FR-027, US5 scenario 4,
// Constitution VI: a card, never a modal).
import 'dart:convert';

import 'package:drift/drift.dart' hide Column, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/plan/domain/adaptation_provider.dart';
import 'package:tekto/features/plan/ui/adaptation_card.dart';
import 'package:tekto/features/plan/ui/adaptation_summary_screen.dart';
import 'package:tekto/features/workout/domain/live_session.dart';
import 'package:tekto/features/workout/domain/workout_providers.dart';
import 'package:tekto/shared/services/local_db/database.dart';

const _entry = <String, dynamic>{
  'week': 1,
  'adapted_at': '2026-11-09T00:00:00Z',
  'adaptations': [
    {
      'plan_exercise_id': 'pe-squat-w2',
      'field_changed': 'suggested_weight_kg',
      'old_value': 60.0,
      'new_value': 62.5,
      'reason_en': 'You hit every rep — time to add weight.',
      'reason_fr': 'Toutes vos répétitions — on ajoute du poids.',
    },
    {
      'plan_exercise_id': 'pe-pushup-w2',
      'field_changed': 'reps_max',
      'old_value': 12,
      'new_value': 13,
      'reason_en': 'One more rep next week.',
      'reason_fr': 'Une répétition de plus.',
    },
  ],
  'sessions_scheduled': 3,
  'sessions_completed': 2,
  'summary_en': '2 of 3 sessions done. 2 changes for next week.',
  'summary_fr': 'Séances faites : 2 sur 3. 2 changements pour la semaine prochaine.',
};

void main() {
  late AppDatabase db;

  Future<void> seed() async {
    await db.batch((b) {
      b.insert(db.plans, PlansCompanion.insert(
          id: 'plan-1', userId: 'u-1', name: 'Plan', weeksTotal: 4, adaptationLog: Value(jsonEncode([_entry]))));
      b.insert(db.sessions, SessionsCompanion.insert(
          id: 'w2-s0', planId: 'plan-1', weekNumber: 2, dayOfWeek: 1, nameEn: 'A', nameFr: 'A', muscleGroups: '[]'));
      for (final (slug, en, fr) in [('goblet-squat', 'Goblet squat', 'Squat gobelet'), ('push-up', 'Push-up', 'Pompe')]) {
        b.insert(db.exercises, ExercisesCompanion.insert(
          slug: slug, nameEn: en, nameFr: fr, equipment: '[]', musclePrimary: '[]',
          muscleSecondary: '[]', cuesEn: '[]', cuesFr: '[]', commonMistakesEn: '[]', commonMistakesFr: '[]'));
      }
      b.insert(db.planExercises, PlanExercisesCompanion.insert(
          id: 'pe-squat-w2', sessionId: 'w2-s0', exerciseSlug: 'goblet-squat', sets: 3, repsMin: 8, repsMax: 12));
      b.insert(db.planExercises, PlanExercisesCompanion.insert(
          id: 'pe-pushup-w2', sessionId: 'w2-s0', exerciseSlug: 'push-up', sets: 3, repsMin: 8, repsMax: 12));
    });
  }

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {String unit = 'kg', Locale locale = const Locale('en')}) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Column(children: [AdaptationCard(), Text('PLAN')]))),
      GoRoute(
        path: '/plan/adaptation',
        builder: (_, s) => AdaptationSummaryScreen(summary: s.extra! as AdaptationSummary),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue('u-1'),
        userPrefsProvider.overrideWith((ref) async => UserPrefs(unit: unit)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  /// Unmounts inside the test so Drift's stream-close timer fires before the invariant check.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('the card shows the week summary inline, in the user language, never as a dialog', (tester) async {
    await tester.runAsync(seed);
    await pump(tester, locale: const Locale('fr'));
    expect(find.textContaining('Séances faites : 2 sur 3'), findsOneWidget);
    expect(find.text('PLAN'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await unmount(tester);
  });

  testWidgets('"Why?" opens the summary: sessions done, old → new in the user unit, exercise names, reasons',
      (tester) async {
    await tester.runAsync(seed);
    await pump(tester, unit: 'lb');
    await tester.tap(find.text('Why?'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('2 of 3 sessions completed'), findsOneWidget);
    expect(find.text('Goblet squat'), findsOneWidget);
    expect(find.textContaining('132.3 → 137.8 lb'), findsOneWidget); // 60 → 62.5 kg
    expect(find.textContaining('12 → 13 reps'), findsOneWidget);
    expect(find.text('You hit every rep — time to add weight.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('dismissing the card hides it for good (stored on the device)', (tester) async {
    await tester.runAsync(seed);
    await pump(tester);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 of 3 sessions done'), findsNothing);
    final plan = (await tester.runAsync(() => db.select(db.plans).getSingle()))!;
    expect(plan.adaptationSeenWeek, 1);
    await unmount(tester);
  });
}
