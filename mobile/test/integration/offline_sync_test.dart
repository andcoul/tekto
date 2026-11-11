// T046 — offline write-queue flush (Constitution I and V).
//
// Two groups:
//  1. Queue semantics against an in-memory Drift DB and a fake transport — always runs.
//  2. Write offline → reconnect → verify server state, against the local Supabase stack
//     (`supabase start`). Runs when these environment variables are set, skipped otherwise:
//       SUPABASE_URL=http://127.0.0.1:54321
//       SUPABASE_ANON_KEY=<ANON_KEY from `supabase status`>
//       SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY from `supabase status`>
//
// Plain `test()` is used (not `testWidgets`) so real HTTP is allowed in group 2.
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';
import 'package:uuid/uuid.dart';

/// Records every replayed request; fails any request whose payload `id` is in [failingIds].
class _FakeApi implements TektoDioClient {
  _FakeApi({this.failingIds = const {}, this.offline = false});

  final Set<String> failingIds;
  bool offline;
  final calls = <String>[]; // "<method> <path> <id>"

  Future<Response<T>> _handle<T>(String method, String path, Object? data) async {
    final id = (data is Map ? data['id'] : null) ?? Uri.parse(path).queryParameters['id']?.replaceFirst('eq.', '');
    if (offline) {
      throw DioException(requestOptions: RequestOptions(path: path), type: DioExceptionType.connectionError);
    }
    calls.add('$method $path $id');
    if (failingIds.contains(id)) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(requestOptions: RequestOptions(path: path), statusCode: 409),
        type: DioExceptionType.badResponse,
      );
    }
    return Response<T>(requestOptions: RequestOptions(path: path), statusCode: 201);
  }

  @override
  Future<Response<T>> post<T>(String path, {Object? data, Map<String, dynamic>? queryParameters}) =>
      _handle<T>('POST', path, data);

  @override
  Future<Response<T>> patch<T>(String path, {Object? data}) => _handle<T>('PATCH', path, data);

  @override
  Future<Response<T>> delete<T>(String path, {Object? data}) => _handle<T>('DELETE', path, data);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _set(String id, {double kg = 80, int reps = 5}) => {
      'id': id,
      'workout_log_id': 'wl-1',
      'plan_exercise_id': 'pe-1',
      'set_number': 1,
      'weight_kg': kg,
      'reps': reps,
    };

void main() {
  group('SyncQueue — queue semantics (in-memory DB)', () {
    late AppDatabase db;
    late StreamController<List<ConnectivityResult>> connectivity;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      connectivity = StreamController<List<ConnectivityResult>>.broadcast();
    });

    tearDown(() async {
      await connectivity.close();
      await db.close();
    });

    Future<List<SyncQueueTableData>> rows() =>
        (db.select(db.syncQueueTable)..orderBy([(q) => OrderingTerm.asc(q.id)])).get();

    test('enqueue never touches the network and returns at once', () async {
      final api = _FakeApi(offline: true);
      final queue = SyncQueue(db: db, dio: api, connectivityChanges: connectivity.stream);

      for (var i = 1; i <= 3; i++) {
        await queue.enqueue(operation: 'INSERT', tableName: 'set_logs', payload: _set('s$i'));
      }

      expect(api.calls, isEmpty);
      expect(await queue.pendingCount(), 3);
      queue.dispose();
    });

    test('flush while still offline keeps every row pending and in order', () async {
      final api = _FakeApi(offline: true);
      final queue = SyncQueue(db: db, dio: api, connectivityChanges: connectivity.stream);
      for (var i = 1; i <= 3; i++) {
        await queue.enqueue(operation: 'insert', tableName: 'set_logs', payload: _set('s$i'));
      }

      await queue.flush();

      expect(await queue.pendingCount(), 3, reason: 'no network → nothing is lost');
      queue.dispose();
    });

    test('3 sets logged offline are replayed in order on reconnect and the queue empties', () async {
      final api = _FakeApi();
      final queue = SyncQueue(db: db, dio: api, connectivityChanges: connectivity.stream);
      for (var i = 1; i <= 3; i++) {
        await queue.enqueue(operation: 'INSERT', tableName: 'set_logs', payload: _set('s$i'));
      }

      connectivity.add([ConnectivityResult.wifi]); // reconnect triggers flush
      await Future<void>.delayed(Duration.zero); // let the listener start the flush
      await queue.idle;

      expect(api.calls, ['POST /rest/v1/set_logs s1', 'POST /rest/v1/set_logs s2', 'POST /rest/v1/set_logs s3']);
      expect(await rows(), isEmpty);
      queue.dispose();
    });

    test('a connectivity event that reports "none" does not flush', () async {
      final api = _FakeApi();
      final queue = SyncQueue(db: db, dio: api, connectivityChanges: connectivity.stream);
      await queue.enqueue(operation: 'insert', tableName: 'set_logs', payload: _set('s1'));

      connectivity.add([ConnectivityResult.none]);
      await Future<void>.delayed(Duration.zero);
      await queue.idle;

      expect(api.calls, isEmpty);
      queue.dispose();
    });

    test('a row failing 3 times becomes failed and never blocks later rows', () async {
      final api = _FakeApi(failingIds: {'bad'});
      final queue = SyncQueue(db: db, dio: api, connectivityChanges: connectivity.stream);
      await queue.enqueue(operation: 'insert', tableName: 'set_logs', payload: _set('s1'));
      await queue.enqueue(operation: 'insert', tableName: 'set_logs', payload: _set('bad'));
      await queue.enqueue(operation: 'insert', tableName: 'set_logs', payload: _set('s3'));

      await queue.flush(); // s1, s3 sent; bad → retry 1
      expect(api.calls.where((c) => c.endsWith(' s3')), hasLength(1), reason: 'later row not blocked');
      var left = await rows();
      expect(left.single.status, 'pending');
      expect(left.single.retryCount, 1);

      await queue.flush(); // retry 2
      await queue.flush(); // retry 3 → failed
      left = await rows();
      expect(left.single.status, 'failed');
      expect(left.single.retryCount, 3);
      expect(await queue.pendingCount(), 0);

      final before = api.calls.length;
      await queue.flush(); // failed rows are not retried automatically
      expect(api.calls.length, before);

      // A row enqueued after the failure still goes through.
      await queue.enqueue(operation: 'insert', tableName: 'set_logs', payload: _set('s5'));
      await queue.flush();
      expect(api.calls.last, 'POST /rest/v1/set_logs s5');
      queue.dispose();
    });

    test('two overlapping flushes send each row exactly once', () async {
      final api = _FakeApi();
      final queue = SyncQueue(db: db, dio: api, connectivityChanges: connectivity.stream);
      for (var i = 1; i <= 3; i++) {
        await queue.enqueue(operation: 'insert', tableName: 'set_logs', payload: _set('s$i'));
      }

      await Future.wait([queue.flush(), queue.flush()]);

      expect(api.calls, hasLength(3));
      queue.dispose();
    });

    test('update and delete replay against the row id', () async {
      final api = _FakeApi();
      final queue = SyncQueue(db: db, dio: api, connectivityChanges: connectivity.stream);
      await queue.enqueue(operation: 'UPDATE', tableName: 'workout_logs', payload: {'id': 'wl-1', 'effort_rating': 8});
      await queue.enqueue(operation: 'delete', tableName: 'set_logs', payload: {'id': 's9'});

      await queue.flush();

      expect(api.calls, ['PATCH /rest/v1/workout_logs?id=eq.wl-1 wl-1', 'DELETE /rest/v1/set_logs?id=eq.s9 s9']);
      queue.dispose();
    });
  });

  // ── Server round trip ─────────────────────────────────────────────────────
  final env = Platform.environment;
  final url = env['SUPABASE_URL'];
  final anonKey = env['SUPABASE_ANON_KEY'];
  final serviceKey = env['SUPABASE_SERVICE_ROLE_KEY'];
  final skipServer = (url == null || anonKey == null || serviceKey == null)
      ? 'Set SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY (local `supabase start`) to run'
      : false;

  group('SyncQueue — write offline → reconnect → verify server state', () {
    late Dio admin;
    late String userId;

    setUpAll(() async {
      if (skipServer != false) return;
      admin = Dio(BaseOptions(
        baseUrl: url!,
        headers: {'apikey': serviceKey, 'Authorization': 'Bearer $serviceKey'},
      ));
    });

    tearDown(() async {
      if (skipServer != false) return;
      // Deleting the auth user cascades to users → plans → sessions → logs.
      await admin.delete<dynamic>('/auth/v1/admin/users/$userId');
    });

    test('3 sets logged offline appear in set_logs after the queue flushes', () async {
      const uuid = Uuid();
      final email = 'sync-${uuid.v4()}@example.test';
      const password = 'sync-test-password-1';

      // ---- Arrange: a real user with a plan, a session and one plan exercise ----
      final created = await admin.post<Map<String, dynamic>>('/auth/v1/admin/users',
          data: {'email': email, 'password': password, 'email_confirm': true});
      userId = created.data!['id'] as String;

      final login = await Dio(BaseOptions(baseUrl: url!, headers: {'apikey': anonKey}))
          .post<Map<String, dynamic>>('/auth/v1/token?grant_type=password', data: {'email': email, 'password': password});
      final accessToken = login.data!['access_token'] as String;

      final planId = uuid.v4(), sessionId = uuid.v4(), planExerciseId = uuid.v4();
      await admin.post<dynamic>('/rest/v1/users', data: {
        'id': userId, 'goal': 'muscle', 'level': 'beginner', 'days_per_week': 3, 'session_length_min': 45,
      });
      await admin.post<dynamic>('/rest/v1/plans', data: {
        'id': planId, 'user_id': userId, 'name': 'Sync test', 'weeks_total': 4,
        'start_date': '2026-11-09', 'source': 'ai',
      });
      await admin.post<dynamic>('/rest/v1/sessions', data: {
        'id': sessionId, 'plan_id': planId, 'week_number': 1, 'day_of_week': 1,
        'name_en': 'Full Body A', 'name_fr': 'Corps entier A',
      });
      await admin.post<dynamic>('/rest/v1/plan_exercises', data: {
        'id': planExerciseId, 'session_id': sessionId, 'exercise_slug': 'goblet-squat',
        'sets': 3, 'reps_min': 8, 'reps_max': 10,
      });

      // ---- Act 1: airplane mode — log a workout and 3 sets ----
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final connectivity = StreamController<List<ConnectivityResult>>.broadcast();
      final api = TektoDioClient(baseUrl: url, anonKey: anonKey!, accessToken: () => accessToken);
      final queue = SyncQueue(db: db, dio: api, connectivityChanges: connectivity.stream);

      final workoutLogId = uuid.v4();
      await queue.enqueue(operation: 'INSERT', tableName: 'workout_logs', payload: {
        'id': workoutLogId, 'user_id': userId, 'session_id': sessionId,
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });
      for (var i = 1; i <= 3; i++) {
        await queue.enqueue(operation: 'INSERT', tableName: 'set_logs', payload: {
          'id': uuid.v4(), 'workout_log_id': workoutLogId, 'plan_exercise_id': planExerciseId,
          'set_number': i, 'weight_kg': 20.0 + i, 'reps': 8, 'rpe_actual': 7.5,
          'logged_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      Future<int> serverSetCount() async {
        final r = await admin.get<List<dynamic>>('/rest/v1/set_logs',
            queryParameters: {'workout_log_id': 'eq.$workoutLogId', 'select': 'id'});
        return r.data!.length;
      }

      expect(await serverSetCount(), 0, reason: 'nothing reaches the server while offline');
      expect(await queue.pendingCount(), 4);

      // ---- Act 2: connectivity restored ----
      connectivity.add([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero); // let the listener start the flush
      await queue.idle;

      // ---- Assert: server state ----
      expect(await serverSetCount(), 3);
      expect(await queue.pendingCount(), 0);
      final failed = await (db.select(db.syncQueueTable)..where((q) => q.status.equals('failed'))).get();
      expect(failed, isEmpty);

      queue.dispose();
      await connectivity.close();
      await db.close();
    }, skip: skipServer, timeout: const Timeout(Duration(seconds: 60)));
  });
}
