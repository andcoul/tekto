import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/form_check/data/form_check_repository.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/form_check/form_score_calculator.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

// ---------------------------------------------------------------------------
// T065 — saving a form check: local row + sync queue, privacy defaults
// ---------------------------------------------------------------------------

class _OfflineApi implements TektoDioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('network used: ${invocation.memberName}');
}

const _summary = FormSetSummary(
  score: 72,
  cuesShown: ['knee_cave'],
  topTipEn: 'Push your knees out',
  topTipFr: 'Poussez vos genoux',
  repCount: 5,
  flaggedReps: [2, 4],
);

void main() {
  late AppDatabase db;
  late SyncQueue queue;
  late FormCheckRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db: db, dio: _OfflineApi(), connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
    repo = FormCheckRepository(db: db, queue: queue);
  });

  tearDown(() async {
    queue.dispose();
    await db.close();
  });

  test('saves the summary locally with flagged reps and the free-try flag', () async {
    final id = await repo.saveSession(userId: 'u1', exerciseSlug: 'barbell-back-squat', summary: _summary, wasFreeTry: true);

    final row = await (db.select(db.formCheckSessions)..where((f) => f.id.equals(id))).getSingle();
    expect(row.userId, 'u1');
    expect(row.repCount, 5);
    expect(row.formScore, 72);
    expect(jsonDecode(row.flaggedReps), [2, 4]);
    expect(jsonDecode(row.cuesShown), ['knee_cave']);
    expect(row.wasFreeTry, isTrue);
    expect(row.userShared, isFalse);
  });

  test('queues a server insert with a UUID id and user_shared = false', () async {
    final id = await repo.saveSession(userId: 'u1', exerciseSlug: 'barbell-back-squat', summary: _summary, wasFreeTry: false, workoutLogId: 'log-1');

    final queued = await db.select(db.syncQueueTable).getSingle();
    expect(queued.operation, 'insert');
    expect(queued.tableName_, 'form_check_sessions');
    final payload = jsonDecode(queued.payload) as Map<String, dynamic>;
    expect(payload['id'], id);
    expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(payload, containsPair('flagged_reps', [2, 4]));
    expect(payload, containsPair('cues_shown', ['knee_cave']));
    expect(payload, containsPair('was_free_try', false));
    expect(payload, containsPair('user_shared', false));
    expect(payload, containsPair('workout_log_id', 'log-1'));
    expect(payload, containsPair('rep_count', 5));
  });

  test('never stores image data: only summary fields are written', () async {
    await repo.saveSession(userId: 'u1', exerciseSlug: 'barbell-back-squat', summary: _summary, wasFreeTry: false);
    final payload = jsonDecode((await db.select(db.syncQueueTable).getSingle()).payload) as Map<String, dynamic>;
    expect(payload.keys, unorderedEquals([
      'id', 'user_id', 'exercise_slug', 'workout_log_id', 'rep_count', 'form_score', 'cues_shown', //
      'flagged_reps', 'top_tip_en', 'top_tip_fr', 'was_free_try', 'user_shared', 'created_at',
    ]));
  });
}
