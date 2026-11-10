import 'package:drift/drift.dart';

import '../database.dart';

part 'workout_dao.g.dart';

@DriftAccessor(tables: [WorkoutLogs, SetLogs, PersonalRecords])
class WorkoutDao extends DatabaseAccessor<AppDatabase> with _$WorkoutDaoMixin {
  WorkoutDao(super.db);

  Future<WorkoutLog?> getActiveLog(String userId) =>
      (select(workoutLogs)
            ..where((w) => w.userId.equals(userId) & w.finishedAt.isNull()))
          .getSingleOrNull();

  Future<List<WorkoutLog>> getHistory(String userId, {int limit = 20}) =>
      (select(workoutLogs)
            ..where((w) => w.userId.equals(userId) & w.finishedAt.isNotNull())
            ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
            ..limit(limit))
          .get();

  Future<String> startWorkout(WorkoutLogsCompanion log) =>
      into(workoutLogs).insert(log).then((_) => log.id.value);

  Future<void> finishWorkout(String logId, int effortRating, double totalVolumeKg) =>
      (update(workoutLogs)..where((w) => w.id.equals(logId))).write(
        WorkoutLogsCompanion(
          finishedAt: Value(DateTime.now()),
          effortRating: Value(effortRating),
          totalVolumeKg: Value(totalVolumeKg),
        ),
      );

  Future<void> insertSetLog(SetLogsCompanion log) => into(setLogs).insert(log);

  Future<List<SetLog>> getSetsForLog(String workoutLogId) =>
      (select(setLogs)
            ..where((s) => s.workoutLogId.equals(workoutLogId))
            ..orderBy([(s) => OrderingTerm.asc(s.setNumber)]))
          .get();

  Future<PersonalRecord?> getPr(String userId, String exerciseSlug) =>
      (select(personalRecords)
            ..where((pr) => pr.userId.equals(userId) & pr.exerciseSlug.equals(exerciseSlug)))
          .getSingleOrNull();

  Future<List<PersonalRecord>> getAllPrs(String userId) =>
      (select(personalRecords)..where((pr) => pr.userId.equals(userId))).get();

  Future<void> upsertPr(PersonalRecordsCompanion pr) =>
      into(personalRecords).insertOnConflictUpdate(pr);
}
