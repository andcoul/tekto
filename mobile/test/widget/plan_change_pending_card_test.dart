// T078 — the plan-change card describes all four change types (ai-services.md §2 plan_change).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/coach/ui/plan_change_pending_card.dart';
import 'package:tekto/features/workout/domain/live_session.dart';
import 'package:tekto/features/workout/domain/workout_providers.dart';
import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/services/local_db/database.dart';

Map<String, dynamic> _change(String type, [Map<String, dynamic> fields = const {}]) => {
      'type': type,
      'plan_exercise_id': null,
      'session_id': null,
      'week_number': null,
      'target_duration_min': null,
      'old_exercise_slug': null,
      'new_exercise_slug': null,
      'new_weight_kg': null,
      'new_reps_min': null,
      'new_reps_max': null,
      'reason_en': 'Easier on the knees.',
      'reason_fr': 'Plus doux pour les genoux.',
      ...fields,
    };

CoachMessageModel _message(Map<String, dynamic> change, {bool applied = false}) => CoachMessageModel(
      id: 'm-1',
      conversationId: 'c-1',
      role: 'assistant',
      content: 'Here is what would change:',
      planChangeProposed: change,
      planChangeApplied: applied,
      createdAt: DateTime(2026, 11, 16),
    );

Future<void> _pump(WidgetTester tester, CoachMessageModel message, {String unit = 'kg', Locale locale = const Locale('en')}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  for (final (slug, en, fr) in [
    ('barbell-back-squat', 'Barbell back squat', 'Squat arrière à la barre'),
    ('leg-press', 'Leg press', 'Presse à cuisses'),
  ]) {
    await db.into(db.exercises).insert(ExercisesCompanion.insert(
          slug: slug,
          nameEn: en,
          nameFr: fr,
          equipment: '[]',
          musclePrimary: '[]',
          muscleSecondary: '[]',
          cuesEn: '[]',
          cuesFr: '[]',
          commonMistakesEn: '[]',
          commonMistakesFr: '[]',
          videoFrontUrl: const Value('https://v/1'),
        ));
  }
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      userPrefsProvider.overrideWith((ref) async => UserPrefs(unit: unit)),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PlanChangePendingCard(message: message)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('exercise swap: old → new by name, with the reason', (tester) async {
    await _pump(tester, _message(_change('exercise_swap', {
      'plan_exercise_id': 'pe-1',
      'old_exercise_slug': 'barbell-back-squat',
      'new_exercise_slug': 'leg-press',
    })));
    expect(find.text('Swap Barbell back squat → Leg press'), findsOneWidget);
    expect(find.text('Easier on the knees.'), findsOneWidget);
    expect(find.text('Apply change'), findsOneWidget);
    expect(find.text('No thanks'), findsOneWidget);
  });

  testWidgets('shortened session: the new length', (tester) async {
    await _pump(tester, _message(_change('session_shorten', {'session_id': 's-1', 'target_duration_min': 35})));
    expect(find.text('Shorten this session to 35 min'), findsOneWidget);
  });

  testWidgets('deload: the week', (tester) async {
    await _pump(tester, _message(_change('deload', {'week_number': 5})));
    expect(find.text('Deload week 5: fewer sets and lighter weights'), findsOneWidget);
  });

  final weightChange = _change('weight_adjustment', {
    'plan_exercise_id': 'pe-1',
    'old_exercise_slug': 'leg-press',
    'new_weight_kg': 100,
    'new_reps_min': 8,
    'new_reps_max': 10,
  });

  testWidgets('weight and reps in kg', (tester) async {
    await _pump(tester, _message(weightChange));
    expect(find.text('Leg press: 100 kg × 8–10 reps'), findsOneWidget);
  });

  testWidgets('weight and reps in lb for lb users (stored in kg)', (tester) async {
    await _pump(tester, _message(weightChange), unit: 'lb');
    expect(find.text('Leg press: 220.5 lb × 8–10 reps'), findsOneWidget);
  });

  testWidgets('weight only', (tester) async {
    await _pump(tester, _message(_change('weight_adjustment', {'old_exercise_slug': 'leg-press', 'new_weight_kg': 60})));
    expect(find.text('Leg press: 60 kg'), findsOneWidget);
  });

  testWidgets('reps only', (tester) async {
    await _pump(tester, _message(_change('weight_adjustment', {'old_exercise_slug': 'leg-press', 'new_reps_min': 12, 'new_reps_max': 15})));
    expect(find.text('Leg press: 12–15 reps'), findsOneWidget);
  });

  testWidgets('French: names, description, reason and buttons', (tester) async {
    await _pump(
      tester,
      _message(_change('exercise_swap', {'old_exercise_slug': 'barbell-back-squat', 'new_exercise_slug': 'leg-press'})),
      locale: const Locale('fr'),
    );
    expect(find.text('Remplacer Squat arrière à la barre par Presse à cuisses'), findsOneWidget);
    expect(find.text('Plus doux pour les genoux.'), findsOneWidget);
    expect(find.text('Non merci'), findsOneWidget);
  });

  testWidgets('an applied change shows its status instead of the buttons', (tester) async {
    await _pump(tester, _message(_change('deload', {'week_number': 5}), applied: true));
    expect(find.text('Change applied'), findsOneWidget);
    expect(find.text('Apply change'), findsNothing);
  });

  testWidgets('an unknown slug falls back to the slug itself', (tester) async {
    await _pump(tester, _message(_change('exercise_swap', {'old_exercise_slug': 'mystery-move', 'new_exercise_slug': 'leg-press'})));
    expect(find.text('Swap mystery-move → Leg press'), findsOneWidget);
  });
}
