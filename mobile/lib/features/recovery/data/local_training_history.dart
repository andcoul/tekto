// Reads the device's workout history for recovery (FR-051) and the Profile tab (FR-053).
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../shared/models/muscle_groups.dart';
import '../../../shared/services/local_db/database.dart';
import '../../profile/domain/profile_stats.dart';
import '../domain/recovery.dart';

class LocalTrainingHistory {
  LocalTrainingHistory(this._db);
  final AppDatabase _db;

  /// Sets per muscle group per finished workout since [since].
  Future<List<TrainedMuscle>> trainedSince(String userId, DateTime since) async {
    final rows = await _db.customSelect(
      'SELECT w.id AS log_id, w.finished_at AS finished_at, w.effort_rating AS effort, e.muscle_primary AS muscles, '
      'COUNT(s.id) AS sets '
      'FROM workout_logs w '
      'JOIN set_logs s ON s.workout_log_id = w.id '
      'JOIN plan_exercises pe ON pe.id = s.plan_exercise_id '
      'JOIN exercises e ON e.slug = pe.exercise_slug '
      'WHERE w.user_id = ? AND w.finished_at IS NOT NULL AND w.finished_at >= ? '
      'GROUP BY w.id, e.slug',
      variables: [Variable.withString(userId), Variable.withDateTime(since)],
      readsFrom: {_db.workoutLogs, _db.setLogs, _db.planExercises, _db.exercises},
    ).get();
    // Group by (workout, muscle group): an exercise's sets count for each of its primary muscles.
    final acc = <(String, String), (int, DateTime, int?)>{};
    for (final r in rows) {
      final finished = r.read<DateTime>('finished_at');
      final effort = r.readNullable<int>('effort');
      final sets = r.read<int>('sets');
      for (final m in (jsonDecode(r.read<String>('muscles')) as List).cast<String>()) {
        final g = muscleGroupOf(m);
        if (g == null) continue;
        final k = (r.read<String>('log_id'), g);
        final prev = acc[k];
        acc[k] = (sets + (prev?.$1 ?? 0), finished, effort);
      }
    }
    return [
      for (final e in acc.entries)
        TrainedMuscle(group: e.key.$2, sets: e.value.$1, finishedAt: e.value.$2, effort: e.value.$3),
    ];
  }

  Future<List<WorkoutDay>> finishedWorkouts(String userId) async {
    final q = _db.select(_db.workoutLogs)..where((w) => w.userId.equals(userId) & w.finishedAt.isNotNull());
    return [for (final w in await q.get()) WorkoutDay(w.finishedAt!, w.totalVolumeKg ?? 0)];
  }

  /// Form-check lift keys with a personal record (badges).
  Future<Set<String>> recordLifts(String userId) async {
    final rows = await _db.customSelect(
      'SELECT DISTINCT e.form_check_lift_key AS k FROM personal_records p JOIN exercises e ON e.slug = p.exercise_slug '
      'WHERE p.user_id = ? AND e.form_check_lift_key IS NOT NULL',
      variables: [Variable.withString(userId)],
      readsFrom: {_db.personalRecords, _db.exercises},
    ).get();
    return {for (final r in rows) r.read<String>('k')};
  }

  Future<User?> user(String userId) => (_db.select(_db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();

  Future<double?> latestBodyWeightKg(String userId) async {
    final q = _db.select(_db.bodyWeightEntries)
      ..where((b) => b.userId.equals(userId))
      ..orderBy([(b) => OrderingTerm.desc(b.measuredOn)])
      ..limit(1);
    return (await q.getSingleOrNull())?.weightKg;
  }
}

final localTrainingHistoryProvider =
    Provider<LocalTrainingHistory>((ref) => LocalTrainingHistory(ref.watch(appDatabaseProvider)));

/// Recovery now for the signed-in user (FR-051).
final recoveryProvider = FutureProvider.autoDispose<Map<String, MuscleRecovery>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const {};
  final now = ref.watch(clockProvider)();
  final trained = await ref.watch(localTrainingHistoryProvider).trainedSince(userId, now.subtract(recoveryWindow));
  return computeRecovery(trained, now);
});
