// T105 — workout summary (US2 acceptance scenario 4, FR-012, FR-034).
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/workout/domain/workout_providers.dart';
import 'package:tekto/features/workout/ui/workout_summary_screen.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/health/health_sync_service.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

import '../helpers/workout_fixtures.dart';

class _OfflineApi implements TektoDioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('offline');
}

/// Health that never answers — finishing must still go home at once.
class _HangingHealth implements HealthPlatform {
  int writes = 0;
  @override
  Future<bool> requestAuthorization() async => true;
  @override
  Future<bool> writeStrengthWorkout({required DateTime start, required DateTime end}) {
    writes++;
    return Completer<bool>().future;
  }
}

void main() {
  late AppDatabase db;
  late SyncQueue queue;

  Future<void> seed(WidgetTester tester, {String unit = 'kg', bool healthSync = false}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db: db, dio: _OfflineApi(), connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
    await tester.runAsync(() async {
      await seedWorkoutFixture(db, unit: unit, healthSync: healthSync);
      await db.into(db.workoutLogs).insert(WorkoutLogsCompanion.insert(id: 'wl-1', userId: kUserId, sessionId: kSessionId));
      await db.batch((b) => b.insertAll(db.setLogs, [
            SetLogsCompanion.insert(id: 'a', workoutLogId: 'wl-1', planExerciseId: 'pe-squat', setNumber: 1, weightKg: 20, reps: 10, isPr: const Value(true)),
            SetLogsCompanion.insert(id: 'b', workoutLogId: 'wl-1', planExerciseId: 'pe-squat', setNumber: 2, weightKg: 20, reps: 8),
            SetLogsCompanion.insert(id: 'c', workoutLogId: 'wl-1', planExerciseId: 'pe-pushup', setNumber: 1, weightKg: 0, reps: 12),
          ]));
    });
  }

  tearDown(() async {
    queue.dispose();
    await db.close();
  });

  Future<_HangingHealth> pumpSummary(WidgetTester tester) async {
    final health = _HangingHealth();
    final router = GoRouter(initialLocation: '/summary', routes: [
      GoRoute(path: '/summary', builder: (_, __) => const WorkoutSummaryScreen(sessionId: kSessionId, workoutLogId: 'wl-1')),
      GoRoute(path: '/home', builder: (_, __) => const Text('home screen')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        syncQueueProvider.overrideWithValue(queue),
        currentUserIdProvider.overrideWithValue(kUserId),
        healthPlatformProvider.overrideWithValue(health),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    return health;
  }

  Future<void> tapFinish(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Finish'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  }

  testWidgets('shows total volume, exercises completed and PRs from the logged sets', (tester) async {
    await seed(tester);
    await pumpSummary(tester);

    expect(find.text('360 kg'), findsOneWidget); // 20×10 + 20×8 + 0×12
    expect(find.text('2'), findsOneWidget); // exercises
    expect(find.text('1'), findsOneWidget); // PRs
    expect(find.text('How hard was that session overall?'), findsOneWidget);
  });

  testWidgets('lb users see the volume in lb', (tester) async {
    await seed(tester, unit: 'lb');
    await pumpSummary(tester);

    expect(find.text('794 lb'), findsOneWidget); // 360 kg
  });

  testWidgets('Finish saves the effort rating, total volume and finish time, then goes home', (tester) async {
    await seed(tester);
    await pumpSummary(tester);
    await tester.drag(find.byKey(const Key('effort-slider')), const Offset(500, 0)); // → 10
    await tester.pumpAndSettle();

    await tapFinish(tester);

    final log = (await tester.runAsync(() => db.select(db.workoutLogs).getSingle()))!;
    expect(log.finishedAt, isNotNull);
    expect(log.effortRating, 10);
    expect(log.totalVolumeKg, 360);
    expect(find.text('home screen'), findsOneWidget);
  });

  testWidgets('Health that never answers does not keep the user on the summary', (tester) async {
    await seed(tester, healthSync: true);
    final health = await pumpSummary(tester);

    await tapFinish(tester);

    expect(health.writes, 1, reason: 'sync was attempted because the user opted in');
    expect(find.text('home screen'), findsOneWidget);

    // The background sync gives up after its 10 s timeout; nothing was marked synced.
    await tester.pump(const Duration(seconds: 11));
    final log = (await tester.runAsync(() => db.select(db.workoutLogs).getSingle()))!;
    expect(log.syncedToHealth, isFalse);
  });

  testWidgets('no Health write when the user has not opted in', (tester) async {
    await seed(tester);
    final health = await pumpSummary(tester);

    await tapFinish(tester);

    expect(health.writes, 0);
  });
}
