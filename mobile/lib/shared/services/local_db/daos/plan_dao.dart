import 'package:drift/drift.dart';

import '../database.dart';

part 'plan_dao.g.dart';

@DriftAccessor(tables: [Plans, Sessions, PlanExercises])
class PlanDao extends DatabaseAccessor<AppDatabase> with _$PlanDaoMixin {
  PlanDao(super.db);

  /// The active plan for the authenticated user.
  Future<Plan?> getActivePlan(String userId) =>
      (select(plans)
            ..where((p) => p.userId.equals(userId) & p.status.equals('active')))
          .getSingleOrNull();

  Stream<Plan?> watchActivePlan(String userId) =>
      (select(plans)
            ..where((p) => p.userId.equals(userId) & p.status.equals('active')))
          .watchSingleOrNull();

  Future<Plan?> getPlanById(String id) =>
      (select(plans)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<List<Session>> getSessionsForPlan(String planId) =>
      (select(sessions)
            ..where((s) => s.planId.equals(planId))
            ..orderBy([(s) => OrderingTerm.asc(s.weekNumber), (s) => OrderingTerm.asc(s.dayOfWeek)]))
          .get();

  Future<List<PlanExercise>> getExercisesForSession(String sessionId) =>
      (select(planExercises)
            ..where((pe) => pe.sessionId.equals(sessionId))
            ..orderBy([(pe) => OrderingTerm.asc(pe.sortOrder)]))
          .get();

  Future<void> upsertPlan(PlansCompanion plan) =>
      into(plans).insertOnConflictUpdate(plan);

  Future<void> upsertSessions(List<SessionsCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(sessions, rows));

  Future<void> upsertPlanExercises(List<PlanExercisesCompanion> rows) =>
      batch((b) => b.insertAllOnConflictUpdate(planExercises, rows));

  /// Mirrors the server's week boundary / adaptation state (adapt-plan, FR-026).
  Future<void> updateWeekState(String planId, {required int currentWeek, required int lastAdaptedWeek}) =>
      (update(plans)..where((p) => p.id.equals(planId))).write(PlansCompanion(
        currentWeek: Value(currentWeek),
        lastAdaptedWeek: Value(lastAdaptedWeek),
      ));

  Future<void> archivePlan(String planId) => (update(plans)
        ..where((p) => p.id.equals(planId)))
      .write(PlansCompanion(status: const Value('archived')));
}
