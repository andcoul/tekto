import 'package:drift/drift.dart';

import '../database.dart';

part 'form_check_dao.g.dart';

@DriftAccessor(tables: [FormCheckSessions, Exercises])
class FormCheckDao extends DatabaseAccessor<AppDatabase> with _$FormCheckDaoMixin {
  FormCheckDao(super.db);

  Future<void> insertSession(FormCheckSessionsCompanion session) =>
      into(formCheckSessions).insert(session);

  Future<List<FormCheckSession>> getForUser(String userId) =>
      (select(formCheckSessions)
            ..where((f) => f.userId.equals(userId))
            ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]))
          .get();

  Future<FormCheckSession?> getById(String id) =>
      (select(formCheckSessions)..where((f) => f.id.equals(id))).getSingleOrNull();

  /// True when the user already used their free form-check try for [liftKey] (FR-029).
  /// Sessions store the exercise slug, so the lift key comes from the exercises table.
  /// Reads the local mirror only, so it works offline.
  Future<bool> hasFreeTry(String userId, String liftKey) async {
    final query = select(formCheckSessions).join([
      innerJoin(exercises, exercises.slug.equalsExp(formCheckSessions.exerciseSlug)),
    ])
      ..where(formCheckSessions.userId.equals(userId) &
          formCheckSessions.wasFreeTry.equals(true) &
          exercises.formCheckLiftKey.equals(liftKey))
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }
}
