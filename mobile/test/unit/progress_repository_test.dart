// T117 — written before progress_repository.dart (FR-039, FR-040, FR-041). Everything is read
// from the device DB, so progress works offline (Constitution I).
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/progress/data/progress_repository.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

import '../helpers/workout_fixtures.dart';

final kNow = DateTime(2026, 11, 15, 10); // Sunday

/// Seeds two finished workouts: one this week, one 6 weeks ago (outside the free window).
Future<void> seedHistory(AppDatabase db) async {
  await seedWorkoutFixture(db);
  await db.batch((b) {
    b.insertAll(db.workoutLogs, [
      WorkoutLogsCompanion.insert(id: 'w-recent', userId: kUserId, sessionId: kSessionId,
          startedAt: Value(kWednesday), finishedAt: Value(kWednesday.add(const Duration(minutes: 45)))),
      WorkoutLogsCompanion.insert(id: 'w-old', userId: kUserId, sessionId: kSessionId,
          startedAt: Value(DateTime(2026, 9, 30, 18)), finishedAt: Value(DateTime(2026, 9, 30, 19))),
      // Unfinished workouts never appear in history.
      WorkoutLogsCompanion.insert(id: 'w-open', userId: kUserId, sessionId: kSessionId, startedAt: Value(kNow)),
    ]);
    b.insertAll(db.setLogs, [
      SetLogsCompanion.insert(id: 's1', workoutLogId: 'w-recent', planExerciseId: 'pe-squat', setNumber: 1, weightKg: 20, reps: 10, loggedAt: Value(kWednesday)),
      SetLogsCompanion.insert(id: 's2', workoutLogId: 'w-recent', planExerciseId: 'pe-squat', setNumber: 2, weightKg: 22, reps: 8, loggedAt: Value(kWednesday)),
      SetLogsCompanion.insert(id: 's3', workoutLogId: 'w-recent', planExerciseId: 'pe-pushup', setNumber: 1, weightKg: 0, reps: 12, loggedAt: Value(kWednesday)),
      SetLogsCompanion.insert(id: 's4', workoutLogId: 'w-old', planExerciseId: 'pe-squat', setNumber: 1, weightKg: 18, reps: 10, loggedAt: Value(DateTime(2026, 9, 30, 18))),
    ]);
    b.insert(db.personalRecords, PersonalRecordsCompanion.insert(
        id: 'pr1', userId: kUserId, exerciseSlug: 'goblet-squat', bestWeightKg: 22, bestReps: 8, bestE1rm: 27.87,
        achievedAt: Value(kWednesday)));
  });
}

/// Fails on any network use: progress must work offline.
class _OfflineApi implements TektoDioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('network used while offline: ${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late SyncQueue queue;
  late ProgressRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await seedHistory(db);
    queue = SyncQueue(db: db, dio: _OfflineApi(), connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
    repo = ProgressRepository(db: db, syncQueue: queue, clock: () => kNow);
  });
  tearDown(() async {
    queue.dispose();
    await db.close();
  });

  group('free user: last 4 weeks, no muscle balance', () {
    test('history lists finished workouts in the window with their volume', () async {
      final p = await repo.load(kUserId, isPro: false);
      expect(p.limited, isTrue);
      expect(p.history.map((h) => h.workoutLogId), ['w-recent']);
      expect(p.history.single.sessionNameEn, 'Full Body A');
      expect(p.history.single.totalVolumeKg, 20 * 10 + 22 * 8);
    });

    test('weekly sets per primary muscle, by Monday-start week', () async {
      final p = await repo.load(kUserId, isPro: false);
      expect(p.weeklySets.single.weekStart, DateTime(2026, 11, 9));
      expect(p.weeklySets.single.setsByMuscle, {'quads': 2, 'chest': 1});
      expect(p.balance, isNull);
    });

    test('e1RM trend: best e1RM per exercise per day; unloaded sets ignored', () async {
      final p = await repo.load(kUserId, isPro: false);
      final squat = p.e1rmTrend['goblet-squat']!;
      expect(squat.single.e1rmKg, closeTo(22 * (1 + 8 / 30), 0.01));
      expect(p.e1rmTrend.containsKey('push-up'), isFalse);
    });
  });

  test('Pro: full history and push:pull muscle balance', () async {
    final p = await repo.load(kUserId, isPro: true);
    expect(p.limited, isFalse);
    expect(p.history.map((h) => h.workoutLogId), ['w-recent', 'w-old'], reason: 'newest first');
    expect(p.e1rmTrend['goblet-squat'], hasLength(2));
    expect([p.balance!.pushSets, p.balance!.pullSets], [1, 0]);
  });

  test('records list every personal record with its exercise name', () async {
    final p = await repo.load(kUserId, isPro: false);
    expect(p.records.single.exerciseNameEn, 'Goblet Squat');
    expect([p.records.single.bestWeightKg, p.records.single.bestReps], [22, 8]);
  });

  group('body weight (FR-041)', () {
    test('saved in kg and queued for sync', () async {
      await repo.logBodyWeight(kUserId, 80, day: kNow);
      final p = await repo.load(kUserId, isPro: false);
      expect(p.bodyWeight.single.weightKg, 80);
      expect(p.bodyWeight.single.day, DateTime(2026, 11, 15));
      final q = await db.select(db.syncQueueTable).get();
      expect(q.single.operation, 'insert');
      expect(q.single.tableName_, 'body_weight_entries');
      expect(jsonDecode(q.single.payload), containsPair('measured_on', '2026-11-15'));
    });

    test('a second entry the same day replaces the first (update, same id)', () async {
      await repo.logBodyWeight(kUserId, 80, day: kNow);
      await repo.logBodyWeight(kUserId, 79.5, day: kNow.add(const Duration(hours: 5)));
      final p = await repo.load(kUserId, isPro: false);
      expect(p.bodyWeight.map((b) => b.weightKg), [79.5]);
      final q = await db.select(db.syncQueueTable).get();
      expect(q.map((e) => e.operation), ['insert', 'update']);
      expect(jsonDecode(q[1].payload)['id'], jsonDecode(q[0].payload)['id']);
    });

    test('rejects a non-positive weight', () async {
      expect(() => repo.logBodyWeight(kUserId, 0, day: kNow), throwsArgumentError);
    });
  });
}
