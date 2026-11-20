// T106 — Apple Health / Health Connect sync (FR-012). Written before T107.
// Opt-in only (Constitution II); a Health failure never blocks finishing a workout.
import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/health/health_sync_service.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

class _FakeHealth implements HealthPlatform {
  _FakeHealth({this.authorized = true, this.writeResult = true, this.throwOnWrite = false, this.hang = false});

  bool authorized;
  bool writeResult;
  bool throwOnWrite;
  bool hang;
  final writes = <({DateTime start, DateTime end})>[];
  int authRequests = 0;

  @override
  Future<bool> requestAuthorization() async {
    authRequests++;
    return authorized;
  }

  @override
  Future<bool> writeStrengthWorkout({required DateTime start, required DateTime end}) async {
    if (hang) return Completer<bool>().future; // never completes
    if (throwOnWrite) throw StateError('HealthKit unavailable');
    writes.add((start: start, end: end));
    return writeResult;
  }
}

class _NoApi implements TektoDioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late SyncQueue queue;
  final start = DateTime(2026, 11, 11, 18, 0);
  final end = DateTime(2026, 11, 11, 18, 52);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    queue = SyncQueue(db: db, dio: _NoApi(), connectivityChanges: const Stream<List<ConnectivityResult>>.empty());
    await db.into(db.workoutLogs).insert(WorkoutLogsCompanion.insert(id: 'wl-1', userId: 'u-1', sessionId: 's-1'));
  });

  tearDown(() async {
    queue.dispose();
    await db.close();
  });

  HealthSyncService service(_FakeHealth health) => HealthSyncService(
        platform: health,
        db: db,
        syncQueue: queue,
        timeout: const Duration(milliseconds: 200),
      );

  Future<bool> syncedFlag() async =>
      (await (db.select(db.workoutLogs)..where((w) => w.id.equals('wl-1'))).getSingle()).syncedToHealth;

  Future<List<Map<String, dynamic>>> queuedPayloads() async => (await db.select(db.syncQueueTable).get())
      .map((r) => {'op': r.operation, 'table': r.tableName_, ...jsonDecode(r.payload) as Map<String, dynamic>})
      .toList();

  test('disabled: nothing is written and Health is never asked for permission', () async {
    final health = _FakeHealth();

    final ok = await service(health).syncFinishedWorkout(
        workoutLogId: 'wl-1', healthSyncEnabled: false, start: start, end: end);

    expect(ok, isFalse);
    expect(health.authRequests, 0);
    expect(health.writes, isEmpty);
    expect(await syncedFlag(), isFalse);
    expect(await queuedPayloads(), isEmpty);
  });

  test('enabled: writes one strength-training workout with the real start and end', () async {
    final health = _FakeHealth();

    final ok = await service(health).syncFinishedWorkout(
        workoutLogId: 'wl-1', healthSyncEnabled: true, start: start, end: end);

    expect(ok, isTrue);
    expect(health.writes.single.start, start);
    expect(health.writes.single.end, end);
  });

  test('success sets workout_logs.synced_to_health locally and queues the server update', () async {
    await service(_FakeHealth()).syncFinishedWorkout(
        workoutLogId: 'wl-1', healthSyncEnabled: true, start: start, end: end);

    expect(await syncedFlag(), isTrue);
    expect(await queuedPayloads(), [
      {'op': 'update', 'table': 'workout_logs', 'id': 'wl-1', 'synced_to_health': true},
    ]);
  });

  test('permission denied: no write, flag stays false, no error', () async {
    final health = _FakeHealth(authorized: false);

    final ok = await service(health).syncFinishedWorkout(
        workoutLogId: 'wl-1', healthSyncEnabled: true, start: start, end: end);

    expect(ok, isFalse);
    expect(health.writes, isEmpty);
    expect(await syncedFlag(), isFalse);
  });

  test('the platform reports failure: flag stays false, no error', () async {
    final ok = await service(_FakeHealth(writeResult: false)).syncFinishedWorkout(
        workoutLogId: 'wl-1', healthSyncEnabled: true, start: start, end: end);

    expect(ok, isFalse);
    expect(await syncedFlag(), isFalse);
    expect(await queuedPayloads(), isEmpty);
  });

  test('the platform throws: the call completes normally and returns false', () async {
    final ok = await service(_FakeHealth(throwOnWrite: true)).syncFinishedWorkout(
        workoutLogId: 'wl-1', healthSyncEnabled: true, start: start, end: end);

    expect(ok, isFalse);
    expect(await syncedFlag(), isFalse);
  });

  test('the platform never answers: gives up after the timeout instead of blocking', () async {
    final sw = Stopwatch()..start();

    final ok = await service(_FakeHealth(hang: true)).syncFinishedWorkout(
        workoutLogId: 'wl-1', healthSyncEnabled: true, start: start, end: end);

    expect(ok, isFalse);
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
