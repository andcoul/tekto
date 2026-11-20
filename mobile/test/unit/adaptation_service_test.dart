// T085 — the app's early adaptation trigger and the stored summaries (FR-026, FR-027;
// contracts/backend-api.md §2).
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/plan/data/plan_repository.dart';
import 'package:tekto/features/plan/domain/adaptation_provider.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';

class _FakeApi extends TektoDioClient {
  _FakeApi() : super(accessToken: () => null, baseUrl: 'http://localhost', anonKey: 'test');

  final posts = <Map<String, dynamic>>[];
  Map<String, dynamic> reply = _contractReply;
  bool offline = false;

  @override
  Future<Response<T>> post<T>(String path, {Object? data, Map<String, dynamic>? queryParameters}) async {
    expect(path, '/functions/v1/adapt-plan');
    posts.add(Map<String, dynamic>.from(data! as Map));
    if (offline) throw DioException(requestOptions: RequestOptions(path: path), type: DioExceptionType.connectionError);
    return Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200, data: reply as T);
  }
}

class _FakePlans implements PlanRepository {
  int refreshes = 0;
  @override
  Future<void> refreshActivePlan(String userId) async => refreshes++;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

const _contractReply = <String, dynamic>{
  'week': 1,
  'adaptations': [
    {
      'plan_exercise_id': 'pe-w2',
      'field_changed': 'suggested_weight_kg',
      'old_value': 60.0,
      'new_value': 62.5,
      'reason_en': 'You hit all reps — ready to progress.',
      'reason_fr': 'Toutes les reps — prêt à progresser.',
    },
  ],
  'sessions_scheduled': 2,
  'sessions_completed': 2,
  'already_adapted': false,
  'summary_en': 'Great week!',
  'summary_fr': 'Super semaine !',
};

void main() {
  late AppDatabase db;
  late _FakeApi api;
  late _FakePlans plans;

  Future<void> seed({List<bool> finished = const [true, true]}) async {
    await db.batch((b) {
      b.insert(db.plans, PlansCompanion.insert(id: 'plan-1', userId: 'u-1', name: 'Plan', weeksTotal: 4));
      for (final (i, day) in [1, 3].indexed) {
        b.insert(db.sessions, SessionsCompanion.insert(
          id: 'w1-s$i', planId: 'plan-1', weekNumber: 1, dayOfWeek: day, nameEn: 'A', nameFr: 'A', muscleGroups: '[]'));
        b.insert(db.workoutLogs, WorkoutLogsCompanion.insert(
          id: 'wl-$i', userId: 'u-1', sessionId: 'w1-s$i',
          finishedAt: Value(finished[i] ? DateTime(2026, 11, 4 + 2 * i, 19) : null)));
      }
      b.insert(db.sessions, SessionsCompanion.insert(
          id: 'w2-s0', planId: 'plan-1', weekNumber: 2, dayOfWeek: 1, nameEn: 'A', nameFr: 'A', muscleGroups: '[]'));
    });
  }

  AdaptationService service() => AdaptationService(db: db, api: api, refreshPlan: plans.refreshActivePlan);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _FakeApi();
    plans = _FakePlans();
  });

  tearDown(() => db.close());

  test('the workout that completes the week triggers adapt-plan for that week, then refreshes the plan', () async {
    await seed();
    final summary = await service().afterWorkoutFinished(sessionId: 'w1-s1', userId: 'u-1', isPro: true);
    expect(api.posts, [
      {'plan_id': 'plan-1', 'completed_week': 1},
    ]);
    expect(plans.refreshes, 1);
    expect(summary!.week, 1);
    expect(summary.sessionsCompleted, 2);
    expect(summary.changes.single.planExerciseId, 'pe-w2');
    expect(summary.changes.single.newValue, 62.5);
    expect(summary.summary('fr'), 'Super semaine !');
  });

  test('no call while a session of that week has no finished workout', () async {
    await seed(finished: [true, false]);
    expect(await service().afterWorkoutFinished(sessionId: 'w1-s0', userId: 'u-1', isPro: true), isNull);
    expect(api.posts, isEmpty);
  });

  test('no call for free users (their plan only advances at the week boundary)', () async {
    await seed();
    expect(await service().afterWorkoutFinished(sessionId: 'w1-s1', userId: 'u-1', isPro: false), isNull);
    expect(api.posts, isEmpty);
  });

  test('offline: nothing happens now; the hourly batch adapts the week later', () async {
    await seed();
    api.offline = true;
    expect(await service().afterWorkoutFinished(sessionId: 'w1-s1', userId: 'u-1', isPro: true), isNull);
    expect(plans.refreshes, 0);
  });

  test('the newest unseen summary comes from the cached adaptation log until it is marked seen', () async {
    await seed();
    final log = [
      {..._contractReply, 'week': 1, 'adapted_at': '2026-11-09T00:00:00Z'},
      {..._contractReply, 'week': 2, 'summary_en': 'Week 2', 'adapted_at': '2026-11-16T00:00:00Z'},
    ];
    await (db.update(db.plans)..where((p) => p.id.equals('plan-1')))
        .write(PlansCompanion(adaptationLog: Value(jsonEncode(log))));

    final s = service();
    final plan = await (db.select(db.plans)..where((p) => p.id.equals('plan-1'))).getSingle();
    expect(AdaptationService.unseenSummary(plan)?.week, 2);
    expect(AdaptationService.unseenSummary(plan)?.summary('en'), 'Week 2');

    await s.markSeen('plan-1', 2);
    final after = await (db.select(db.plans)..where((p) => p.id.equals('plan-1'))).getSingle();
    expect(AdaptationService.unseenSummary(after), isNull);
  });

  test('old log entries in another shape are ignored, not a crash', () async {
    await seed();
    await (db.update(db.plans)..where((p) => p.id.equals('plan-1'))).write(PlansCompanion(
        adaptationLog: Value(jsonEncode([
      {'week': 1, 'events': []},
    ]))));
    final plan = await (db.select(db.plans)..where((p) => p.id.equals('plan-1'))).getSingle();
    expect(AdaptationService.unseenSummary(plan), isNull);
  });
}
