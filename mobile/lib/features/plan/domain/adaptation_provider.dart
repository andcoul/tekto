import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/features/plan/domain/plan_provider.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';

// ---------------------------------------------------------------------------
// Weekly adaptation on the app side (FR-026, FR-027; contracts/backend-api.md §2; T085)
// ---------------------------------------------------------------------------
// - Early trigger: right after the workout that completes a training week (every session with
//   that week_number has a finished workout log), a Pro user's app calls adapt-plan. Offline or
//   on any error nothing happens: the hourly batch adapts the week at the boundary.
// - Summaries, from either trigger, arrive with the cached plan (plans.adaptation_log) on the
//   next refresh — i.e. on app open — and are shown as a card until seen (T086).

class AdaptationChange {
  const AdaptationChange({
    required this.planExerciseId,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.reasonEn,
    required this.reasonFr,
  });

  factory AdaptationChange.fromJson(Map<String, dynamic> json) => AdaptationChange(
        planExerciseId: json['plan_exercise_id'] as String,
        field: json['field_changed'] as String,
        oldValue: (json['old_value'] as num).toDouble(),
        newValue: (json['new_value'] as num).toDouble(),
        reasonEn: json['reason_en'] as String? ?? '',
        reasonFr: json['reason_fr'] as String? ?? '',
      );

  final String planExerciseId;

  /// `suggested_weight_kg` or `reps_max`.
  final String field;
  final double oldValue;
  final double newValue;
  final String reasonEn;
  final String reasonFr;

  bool get isWeight => field == 'suggested_weight_kg';
  String reason(String languageCode) => languageCode == 'fr' ? reasonFr : reasonEn;
}

class AdaptationSummary {
  const AdaptationSummary({
    required this.week,
    required this.changes,
    required this.sessionsScheduled,
    required this.sessionsCompleted,
    required this.summaryEn,
    required this.summaryFr,
  });

  /// Parses an adapt-plan response or a plans.adaptation_log entry (same shape); null for
  /// anything else (e.g. log entries written by an older version).
  static AdaptationSummary? tryParse(Object? json) {
    if (json is! Map) return null;
    final m = Map<String, dynamic>.from(json);
    final week = m['week'];
    final changes = m['adaptations'];
    if (week is! int || changes is! List) return null;
    try {
      return AdaptationSummary(
        week: week,
        changes: [for (final c in changes) AdaptationChange.fromJson(Map<String, dynamic>.from(c as Map))],
        sessionsScheduled: (m['sessions_scheduled'] as num?)?.toInt() ?? 0,
        sessionsCompleted: (m['sessions_completed'] as num?)?.toInt() ?? 0,
        summaryEn: m['summary_en'] as String? ?? '',
        summaryFr: m['summary_fr'] as String? ?? '',
      );
    } on Object {
      return null;
    }
  }

  final int week;
  final List<AdaptationChange> changes;
  final int sessionsScheduled;
  final int sessionsCompleted;
  final String summaryEn;
  final String summaryFr;

  String summary(String languageCode) => languageCode == 'fr' ? summaryFr : summaryEn;
}

class AdaptationService {
  AdaptationService({
    required AppDatabase db,
    required TektoDioClient api,
    required Future<void> Function(String userId) refreshPlan,
  })  : _db = db,
        _api = api,
        _refreshPlan = refreshPlan;

  final AppDatabase _db;
  final TektoDioClient _api;

  /// Re-downloads the active plan into the device cache (PlanRepository.refreshActivePlan).
  final Future<void> Function(String userId) _refreshPlan;

  /// Called after a workout of [sessionId] is finished. Returns the summary when this workout
  /// completed its training week and the server adapted it; null otherwise.
  Future<AdaptationSummary?> afterWorkoutFinished({
    required String sessionId,
    required String userId,
    required bool isPro,
  }) async {
    if (!isPro) return null; // free plans only advance at the week boundary (batch)
    final session = await (_db.select(_db.sessions)..where((s) => s.id.equals(sessionId))).getSingleOrNull();
    if (session == null) return null;

    final weekSessions = await (_db.select(_db.sessions)
          ..where((s) => s.planId.equals(session.planId) & s.weekNumber.equals(session.weekNumber)))
        .get();
    final finishedIds = (await (_db.select(_db.workoutLogs)
              ..where((l) => l.sessionId.isIn(weekSessions.map((s) => s.id)) & l.finishedAt.isNotNull()))
            .get())
        .map((l) => l.sessionId)
        .toSet();
    if (!weekSessions.every((s) => finishedIds.contains(s.id))) return null;

    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/functions/v1/adapt-plan',
        data: {'plan_id': session.planId, 'completed_week': session.weekNumber},
      );
      final summary = AdaptationSummary.tryParse(response.data);
      await _refreshPlan(userId); // next week's values + the stored summary
      return summary;
    } on Object {
      return null; // offline, WEEK_NOT_ENDED, …: the batch run adapts the week later
    }
  }

  /// The newest stored summary the user has not dismissed or opened yet.
  static AdaptationSummary? unseenSummary(Plan plan) {
    final Object? log;
    try {
      log = jsonDecode(plan.adaptationLog);
    } on FormatException {
      return null;
    }
    if (log is! List) return null;
    AdaptationSummary? newest;
    for (final entry in log) {
      final s = AdaptationSummary.tryParse(entry);
      if (s != null && s.week > plan.adaptationSeenWeek && (newest == null || s.week > newest.week)) newest = s;
    }
    return newest;
  }

  Future<void> markSeen(String planId, int week) =>
      (_db.update(_db.plans)..where((p) => p.id.equals(planId) & p.adaptationSeenWeek.isSmallerThanValue(week)))
          .write(PlansCompanion(adaptationSeenWeek: Value(week)));
}

final adaptationServiceProvider = Provider<AdaptationService>(
  (ref) => AdaptationService(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(dioClientProvider),
    // Read lazily: the repository needs the Supabase client, which only the network path uses.
    refreshPlan: (userId) => ref.read(planRepositoryProvider).refreshActivePlan(userId),
  ),
);

/// The active plan's newest unseen adaptation summary, with its plan id (for [markSeen]).
final unseenAdaptationProvider = StreamProvider.autoDispose<({String planId, AdaptationSummary summary})?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.plans)..where((p) => p.userId.equals(userId) & p.status.equals('active')))
      .watchSingleOrNull()
      .map((plan) {
    if (plan == null) return null;
    final summary = AdaptationService.unseenSummary(plan);
    return summary == null ? null : (planId: plan.id, summary: summary);
  });
});

/// Exercise names for plan exercise ids (summary screen), from the device cache.
final planExerciseNamesProvider =
    FutureProvider.autoDispose.family<Map<String, ({String en, String fr})>, String>((ref, idsCsv) async {
  final db = ref.watch(appDatabaseProvider);
  final ids = idsCsv.split(',').where((s) => s.isNotEmpty).toList();
  if (ids.isEmpty) return const {};
  final query = db.select(db.planExercises).join([
    innerJoin(db.exercises, db.exercises.slug.equalsExp(db.planExercises.exerciseSlug)),
  ])
    ..where(db.planExercises.id.isIn(ids));
  final rows = await query.get();
  return {
    for (final r in rows)
      r.readTable(db.planExercises).id: (en: r.readTable(db.exercises).nameEn, fr: r.readTable(db.exercises).nameFr),
  };
});
