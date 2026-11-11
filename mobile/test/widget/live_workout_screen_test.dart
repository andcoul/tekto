// T047 — live workout screen (FR-007, FR-008, FR-010, FR-011; Constitution I and VI).
// Written before T050. Runs as a free user with no network for the whole file.
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/features/workout/ui/live_workout_screen.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

import '../helpers/workout_fixtures.dart';

/// Offline transport: every request fails, so nothing leaves the queue.
class _OfflineApi implements TektoDioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('network used while offline: ${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late SyncQueue queue;
  // Drift's writes complete on the real event loop, so DB reads in assertions go
  // through runAsync (the fake clock — and the rest timer — do not move).
  late WidgetTester t;

  Future<void> setUpDb({String unit = 'kg'}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedWorkoutFixture(db, unit: unit);
    queue = SyncQueue(db: db, dio: _OfflineApi(), connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
  }

  tearDown(() async {
    queue.dispose();
    await db.close();
  });

  Future<void> pumpWorkout(WidgetTester tester) async {
    t = tester;
    tester.view.physicalSize = const Size(1080, 2340); // phone portrait, 360×780 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(initialLocation: '/workout/$kSessionId', routes: [
      GoRoute(
        path: '/workout/:sessionId',
        builder: (_, s) => LiveWorkoutScreen(sessionId: s.pathParameters['sessionId']!),
        routes: [GoRoute(path: 'summary', builder: (_, __) => const Text('summary screen'))],
      ),
      GoRoute(path: '/form-check/:slug', builder: (_, __) => const Text('form check')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncQueueProvider.overrideWithValue(queue),
        currentUserIdProvider.overrideWithValue(kUserId),
        clockProvider.overrideWithValue(() => kWednesday),
        isOnlineProvider.overrideWith((ref) => Stream.value(false)),
        entitlementProvider.overrideWith((ref) => Stream.value(EntitlementState.free)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Ends the test with no rest timer running.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Finder primaryActions() => find.byType(ElevatedButton);

  Future<List<SetLog>> setLogs() async =>
      (await t.runAsync(() => (db.select(db.setLogs)..orderBy([(s) => OrderingTerm.asc(s.loggedAt)])).get()))!;

  Future<List<Map<String, dynamic>>> queued(String table) async =>
      (await t.runAsync(() => db.select(db.syncQueueTable).get()))!
          .where((r) => r.tableName_ == table)
          .map((r) => jsonDecode(r.payload) as Map<String, dynamic>)
          .toList();

  Future<void> logCurrentSet(WidgetTester tester, {String? weight, int moreReps = 0, String? rpe}) async {
    if (weight != null) {
      await tester.enterText(find.byKey(const Key('weight-input')), weight);
    }
    for (var i = 0; i < moreReps; i++) {
      await tester.tap(find.byTooltip('More reps'));
      await tester.pump();
    }
    if (rpe != null) {
      await tester.tap(find.byKey(const Key('rpe-select')));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(find.text(rpe), find.byType(Scrollable).last, const Offset(0, -48));
      await tester.pumpAndSettle();
      await tester.tap(find.text(rpe).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(ElevatedButton, 'Done'));
    await tester.pump();
    // Let the local writes finish on the real event loop, then rebuild without
    // advancing the fake clock (so the rest timer has not ticked yet).
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
  }

  testWidgets('loads today\'s first exercise from the local cache with 3 cues and the suggested weight', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    expect(find.text('Goblet Squat'), findsOneWidget);
    expect(find.text('Hold the bell at your chest'), findsOneWidget);
    expect(find.text('Knees track over toes'), findsOneWidget);
    expect(find.text('Sit between your heels'), findsOneWidget);
    expect(find.text('Fourth cue never shown'), findsNothing);
    expect(find.text('Set 1 of 2'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('weight-input'))).controller!.text, '16');
    await unmount(tester);
  });

  testWidgets('free user offline: video area shows the inline Pro notice, no dialog, no overlay', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    expect(find.text('Offline video requires Tekto Pro'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ModalBarrier), findsOneWidget, reason: 'only the route\'s own barrier, no modal on top');
    await unmount(tester);
  });

  testWidgets('logs weight, reps and optional RPE locally and queues the write — no network', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    await logCurrentSet(tester, weight: '18', moreReps: 1, rpe: '8.5');

    final sets = await setLogs();
    expect(sets, hasLength(1));
    expect(sets.single.planExerciseId, 'pe-squat');
    expect(sets.single.setNumber, 1);
    expect(sets.single.weightKg, 18);
    expect(sets.single.reps, 9);
    expect(sets.single.rpeActual, 8.5);

    final q = await queued('set_logs');
    expect(q.single['weight_kg'], 18);
    expect(q.single['rpe_actual'], 8.5);
    expect(await queued('workout_logs'), hasLength(1), reason: 'the workout itself was created offline');
    await unmount(tester);
  });

  testWidgets('RPE is optional', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    await logCurrentSet(tester);

    expect((await setLogs()).single.rpeActual, isNull);
    await unmount(tester);
  });

  testWidgets('the RPE picker offers 1–10 in 0.5 steps', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    final picker = tester.widget<DropdownButton<double?>>(find.byKey(const Key('rpe-select')));
    final values = picker.items!.map((i) => i.value).toList();

    expect(values.first, isNull, reason: 'blank first: RPE is optional');
    expect(values.skip(1), [for (var i = 2; i <= 20; i++) i / 2]);
    await unmount(tester);
  });

  testWidgets('the rest timer starts automatically with plan_exercises.rest_sec and counts down', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    await logCurrentSet(tester);

    expect(find.text('1:30'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1:29'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the running rest can be adjusted by ±15 s, clamped to 15–600 s', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);
    await logCurrentSet(tester);

    await tester.tap(find.byTooltip('Add 15 seconds'));
    await tester.pump();
    expect(find.text('1:45'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove 15 seconds'));
    await tester.tap(find.byTooltip('Remove 15 seconds'));
    await tester.pump();
    expect(find.text('1:15'), findsOneWidget);

    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byTooltip('Remove 15 seconds'));
    }
    await tester.pump();
    expect(find.text('0:15'), findsOneWidget, reason: 'never below 15 s');

    for (var i = 0; i < 50; i++) {
      await tester.tap(find.byTooltip('Add 15 seconds'));
    }
    await tester.pump();
    expect(find.text('10:00'), findsOneWidget, reason: 'never above 600 s');
    await unmount(tester);
  });

  testWidgets('an adjustment applies to the current rest only', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);
    await logCurrentSet(tester);
    await tester.tap(find.byTooltip('Add 15 seconds'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Skip rest'));
    await tester.pump();

    await logCurrentSet(tester); // set 2 of the squat

    expect(find.text('1:30'), findsOneWidget, reason: 'back to the plan\'s rest_sec');
    await unmount(tester);
  });

  testWidgets('a PR shows an inline "New PR" badge on its row at once, without a dialog', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    await logCurrentSet(tester, weight: '18'); // no record yet → PR

    expect(find.text('New PR! 🎉'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect((await setLogs()).single.isPr, isTrue);
    await unmount(tester);
  });

  testWidgets('a lighter set after a PR is not a PR', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);
    await logCurrentSet(tester, weight: '18');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Skip rest'));
    await tester.pump();

    await logCurrentSet(tester, weight: '14');

    expect(find.text('New PR! 🎉'), findsOneWidget, reason: 'only set 1 keeps its badge');
    expect((await setLogs()).map((s) => s.isPr), [true, false]);
    await unmount(tester);
  });

  testWidgets('exactly one primary action is visible in every phase of the workout', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    // Logging: only the current set's Done.
    expect(primaryActions(), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Done'), findsOneWidget);

    // Resting: only Skip rest.
    await logCurrentSet(tester);
    expect(primaryActions(), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Skip rest'), findsOneWidget);

    // Exercise complete: only Next exercise.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Skip rest'));
    await tester.pump();
    await logCurrentSet(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Skip rest'));
    await tester.pump();
    expect(primaryActions(), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Next exercise'), findsOneWidget);

    // Last set of the workout: no rest, only Finish workout.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Push-up'), findsOneWidget);
    await logCurrentSet(tester);
    expect(find.text('1:00'), findsNothing, reason: 'no rest after the final set');
    expect(primaryActions(), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Finish workout'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('bodyweight sets at 0 kg can be logged and are never PRs', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);
    await tester.tap(find.byTooltip('Next exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Push-up'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('weight-input'))).controller!.text, '0');

    await logCurrentSet(tester);

    final sets = await setLogs();
    expect(sets.single.weightKg, 0);
    expect(sets.single.isPr, isFalse);
    expect(find.text('New PR! 🎉'), findsNothing);
    await unmount(tester);
  });

  testWidgets('can move between exercises offline in both directions', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    await tester.tap(find.byTooltip('Next exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Push-up'), findsOneWidget);
    expect(find.text('Hands under shoulders'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Goblet Squat'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Finish workout opens the summary', (tester) async {
    await setUpDb();
    await pumpWorkout(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await tester.pumpAndSettle();

    expect(find.text('summary screen'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('lb users see and enter weights in lb; storage stays in kg', (tester) async {
    await setUpDb(unit: 'lb');
    await pumpWorkout(tester);

    expect(tester.widget<TextField>(find.byKey(const Key('weight-input'))).controller!.text, '35.3');
    expect(find.text('lb'), findsWidgets);

    await logCurrentSet(tester, weight: '40');

    expect((await setLogs()).single.weightKg, closeTo(18.14, 0.01));
    await unmount(tester);
  });

  testWidgets('reopening an unfinished workout resumes it instead of starting a new one', (tester) async {
    await setUpDb();
    await db.into(db.workoutLogs).insert(WorkoutLogsCompanion.insert(id: 'wl-open', userId: kUserId, sessionId: kSessionId));
    await db.into(db.setLogs).insert(SetLogsCompanion.insert(
        id: 'set-1', workoutLogId: 'wl-open', planExerciseId: 'pe-squat', setNumber: 1, weightKg: 16, reps: 8));

    await pumpWorkout(tester);

    expect(find.text('Set 2 of 2'), findsOneWidget);
    expect(await db.select(db.workoutLogs).get(), hasLength(1));
    await logCurrentSet(tester);
    expect((await setLogs()).map((s) => s.workoutLogId).toSet(), {'wl-open'});
    await unmount(tester);
  });
}
