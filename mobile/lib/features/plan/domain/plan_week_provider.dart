import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/shared/services/local_db/database.dart';

/// One plan exercise with its cached library entry (null if not cached yet).
typedef PlanSlot = ({PlanExercise slot, Exercise? exercise});

/// A session of the week and its exercises in order.
typedef PlanDay = ({Session session, List<PlanSlot> exercises});

/// The sessions of [week] of a plan, from the device cache (works offline, Constitution I);
/// updates when the plan cache is refreshed, e.g. after a swap (T138).
final planWeekProvider =
    StreamProvider.autoDispose.family<List<PlanDay>, ({String planId, int week})>((ref, key) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.sessions).join([
    leftOuterJoin(db.planExercises, db.planExercises.sessionId.equalsExp(db.sessions.id)),
    leftOuterJoin(db.exercises, db.exercises.slug.equalsExp(db.planExercises.exerciseSlug)),
  ])
    ..where(db.sessions.planId.equals(key.planId) & db.sessions.weekNumber.equals(key.week))
    ..orderBy([OrderingTerm.asc(db.sessions.dayOfWeek), OrderingTerm.asc(db.planExercises.sortOrder)]);

  return query.watch().map((rows) {
    final days = <String, PlanDay>{};
    for (final r in rows) {
      final session = r.readTable(db.sessions);
      final day = days.putIfAbsent(session.id, () => (session: session, exercises: <PlanSlot>[]));
      final slot = r.readTableOrNull(db.planExercises);
      if (slot != null) day.exercises.add((slot: slot, exercise: r.readTableOrNull(db.exercises)));
    }
    return days.values.toList();
  });
});
