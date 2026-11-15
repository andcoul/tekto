import 'dart:convert';

import 'package:drift/drift.dart';

import '../api/supabase_client.dart';
import '../local_db/database.dart';

/// Downloads the user's training history into the device DB after sign-in on a fresh install
/// (T127): finished workouts with their sets, the sessions and plan exercises they reference
/// (so names and muscles resolve for archived plans), personal records and body weight.
///
/// Runs only when the device has no workout for the user, so it happens once per install.
/// Safe to rerun (rows are upserted). Offline or on any failure it writes nothing and returns
/// false, so the next launch retries. Downloaded rows are never queued for upload.
class HistoryBackfillService {
  HistoryBackfillService({required AppDatabase db, required TektoDioClient api, this.pageSize = 200})
      : _db = db,
        _api = api;

  final AppDatabase _db;
  final TektoDioClient _api;
  final int pageSize;

  /// True when history was downloaded; false when skipped or when it must be retried.
  Future<bool> run(String userId) async {
    final hasLocal = await (_db.select(_db.workoutLogs)
          ..where((w) => w.userId.equals(userId))
          ..limit(1))
        .getSingleOrNull();
    if (hasLocal != null) return false;

    try {
      final logs = <Map<String, dynamic>>[];
      for (var offset = 0;; offset += pageSize) {
        final page = await _rows('workout_logs', {
          'user_id': 'eq.$userId',
          'finished_at': 'not.is.null',
          'order': 'finished_at.desc',
          'offset': '$offset',
          'limit': '$pageSize',
        });
        logs.addAll(page);
        if (page.length < pageSize) break;
      }
      final logIds = logs.map((l) => l['id'] as String).toList();
      final sets = <Map<String, dynamic>>[];
      for (final chunk in _chunks(logIds)) {
        sets.addAll(await _rows('set_logs', {'workout_log_id': 'in.(${chunk.join(',')})'}));
      }
      final sessionIds = logs.map((l) => l['session_id'] as String).toSet().toList();
      final sessions = <Map<String, dynamic>>[];
      for (final chunk in _chunks(sessionIds)) {
        sessions.addAll(await _rows('sessions', {'id': 'in.(${chunk.join(',')})'}));
      }
      final planExerciseIds = sets.map((s) => s['plan_exercise_id'] as String).toSet().toList();
      final planExercises = <Map<String, dynamic>>[];
      for (final chunk in _chunks(planExerciseIds)) {
        planExercises.addAll(await _rows('plan_exercises', {'id': 'in.(${chunk.join(',')})'}));
      }
      final records = await _rows('personal_records', {'user_id': 'eq.$userId'});
      final bodyWeight = await _rows('body_weight_entries', {'user_id': 'eq.$userId'});

      // Everything is fetched before anything is written: a failed download leaves no partial
      // history behind, so the next launch still sees an empty device and retries.
      await _db.batch((b) {
        b.insertAllOnConflictUpdate(_db.sessions, [
          for (final s in sessions)
            SessionsCompanion.insert(
              id: s['id'] as String,
              planId: s['plan_id'] as String,
              weekNumber: s['week_number'] as int,
              dayOfWeek: s['day_of_week'] as int,
              nameEn: s['name_en'] as String,
              nameFr: s['name_fr'] as String,
              muscleGroups: jsonEncode(s['muscle_groups'] ?? const []),
              estimatedMin: Value(s['estimated_min'] as int?),
            ),
        ]);
        b.insertAllOnConflictUpdate(_db.planExercises, [
          for (final e in planExercises)
            PlanExercisesCompanion.insert(
              id: e['id'] as String,
              sessionId: e['session_id'] as String,
              exerciseSlug: e['exercise_slug'] as String,
              sortOrder: Value(e['sort_order'] as int? ?? 0),
              sets: e['sets'] as int,
              repsMin: e['reps_min'] as int,
              repsMax: e['reps_max'] as int,
              rpeTarget: Value((e['rpe_target'] as num?)?.toDouble()),
              rirTarget: Value(e['rir_target'] as int?),
              restSec: Value(e['rest_sec'] as int? ?? 90),
              suggestedWeightKg: Value((e['suggested_weight_kg'] as num?)?.toDouble()),
            ),
        ]);
        b.insertAllOnConflictUpdate(_db.workoutLogs, [
          for (final l in logs)
            WorkoutLogsCompanion.insert(
              id: l['id'] as String,
              userId: l['user_id'] as String,
              sessionId: l['session_id'] as String,
              startedAt: Value(DateTime.parse(l['started_at'] as String).toLocal()),
              finishedAt: Value(_date(l['finished_at'])),
              effortRating: Value(l['effort_rating'] as int?),
              totalVolumeKg: Value((l['total_volume_kg'] as num?)?.toDouble()),
              syncedToHealth: Value(l['synced_to_health'] as bool? ?? false),
            ),
        ]);
        b.insertAllOnConflictUpdate(_db.setLogs, [
          for (final s in sets)
            SetLogsCompanion.insert(
              id: s['id'] as String,
              workoutLogId: s['workout_log_id'] as String,
              planExerciseId: s['plan_exercise_id'] as String,
              setNumber: s['set_number'] as int,
              weightKg: (s['weight_kg'] as num).toDouble(),
              reps: s['reps'] as int,
              rpeActual: Value((s['rpe_actual'] as num?)?.toDouble()),
              isPr: Value(s['is_pr'] as bool? ?? false),
              loggedAt: Value(DateTime.parse(s['logged_at'] as String).toLocal()),
            ),
        ]);
        b.insertAllOnConflictUpdate(_db.personalRecords, [
          for (final r in records)
            PersonalRecordsCompanion.insert(
              id: r['id'] as String,
              userId: r['user_id'] as String,
              exerciseSlug: r['exercise_slug'] as String,
              bestWeightKg: (r['best_weight_kg'] as num).toDouble(),
              bestReps: r['best_reps'] as int,
              bestE1rm: (r['best_e1rm'] as num).toDouble(),
              achievedAt: Value(DateTime.parse(r['achieved_at'] as String).toLocal()),
            ),
        ]);
        b.insertAllOnConflictUpdate(_db.bodyWeightEntries, [
          for (final w in bodyWeight)
            BodyWeightEntriesCompanion.insert(
              id: w['id'] as String,
              userId: w['user_id'] as String,
              weightKg: (w['weight_kg'] as num).toDouble(),
              // A calendar date ("2026-11-01"): stored as local midnight, like local entries.
              measuredOn: DateTime.parse(w['measured_on'] as String),
            ),
        ]);
      });
      return true;
    } on Object {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> _rows(String table, Map<String, dynamic> query) async {
    final response = await _api.get<List<dynamic>>('/rest/v1/$table', queryParameters: {'select': '*', ...query});
    return (response.data ?? const []).cast<Map<String, dynamic>>();
  }

  static DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

  /// PostgREST `in.(…)` filters go in the URL; keep each under typical URL limits.
  static Iterable<List<String>> _chunks(List<String> ids, [int size = 100]) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, i + size > ids.length ? ids.length : i + size);
    }
  }
}
