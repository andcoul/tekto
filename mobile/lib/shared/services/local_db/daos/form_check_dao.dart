import 'package:drift/drift.dart';

import '../database.dart';

part 'form_check_dao.g.dart';

@DriftAccessor(tables: [FormCheckSessions])
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
}
