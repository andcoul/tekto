// T138 — the plan shows this week's sessions with their exercises, and any exercise can be
// swapped outside a workout (FR-028 "at any time"; US1 scenario 1: named exercises, sets, reps).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/library/domain/exercise_provider.dart';
import 'package:tekto/features/plan/domain/adaptation_provider.dart';
import 'package:tekto/features/plan/domain/plan_provider.dart';
import 'package:tekto/features/plan/ui/exercise_swap_sheet.dart';
import 'package:tekto/features/plan/ui/plan_overview_screen.dart';
import 'package:tekto/features/workout/domain/live_session.dart';
import 'package:tekto/features/workout/domain/workout_providers.dart';
import 'package:tekto/shared/models/exercise_model.dart';
import 'package:tekto/shared/services/local_db/database.dart';

import '../helpers/workout_fixtures.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {bool online = true, String unit = 'kg'}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/plan', routes: [
      GoRoute(path: '/plan', builder: (_, __) => const PlanOverviewScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWithValue(kUserId),
        activePlanProvider.overrideWith((ref) => Stream.value(fixturePlan())),
        unseenAdaptationProvider.overrideWith((ref) => Stream.value(null)),
        isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        userPrefsProvider.overrideWith((ref) async => UserPrefs(unit: unit, equipment: const ['dumbbell'])),
        exercisesProvider.overrideWith((ref) async => [
              for (final slug in ['goblet-squat', 'dumbbell-lunge'])
                ExerciseModel(
                  slug: slug, nameEn: slug, nameFr: slug, equipment: const ['dumbbell'],
                  musclePrimary: const ['quadriceps'], muscleSecondary: const [], cuesEn: const [], cuesFr: const [],
                  commonMistakesEn: const [], commonMistakesFr: const [], videoFrontUrl: 'v.m3u8', formCheckSupported: false,
                ),
            ]),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  testWidgets('this week: the session day lists its exercises with sets × reps and weight; other days rest',
      (tester) async {
    await tester.runAsync(() => seedWorkoutFixture(db));
    await pump(tester);
    expect(find.text('Full Body A'), findsOneWidget);
    expect(find.text('Full Body A (week 2)'), findsNothing, reason: 'only the current week');
    expect(find.text('Goblet Squat'), findsOneWidget);
    expect(find.textContaining('2 × 8–10'), findsOneWidget);
    expect(find.textContaining('16 kg'), findsOneWidget);
    expect(find.text('Rest day'), findsWidgets, reason: 'Monday and Tuesday are rest days (the list builds lazily)');
    await unmount(tester);
  });

  testWidgets('weights follow the unit setting', (tester) async {
    await tester.runAsync(() => seedWorkoutFixture(db));
    await pump(tester, unit: 'lb');
    expect(find.textContaining('35.3 lb'), findsOneWidget); // 16 kg
    await unmount(tester);
  });

  testWidgets('each exercise has a swap action that opens the rule-based swap sheet (no AI)', (tester) async {
    await tester.runAsync(() => seedWorkoutFixture(db));
    await pump(tester);
    final swaps = find.byTooltip('Swap exercise');
    expect(swaps, findsNWidgets(2));
    await tester.tap(swaps.first);
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseSwapSheet), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('offline, swap is disabled (it needs the server), the plan still shows', (tester) async {
    await tester.runAsync(() => seedWorkoutFixture(db));
    await pump(tester, online: false);
    final button = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.swap_horiz).first);
    expect(button.onPressed, isNull);
    expect(find.text('Goblet Squat'), findsOneWidget);
    await unmount(tester);
  });
}
