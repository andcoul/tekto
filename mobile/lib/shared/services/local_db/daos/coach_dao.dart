import 'package:drift/drift.dart';

import '../database.dart';

part 'coach_dao.g.dart';

@DriftAccessor(tables: [CoachConversations, CoachMessages, CoachQuotaUsage])
class CoachDao extends DatabaseAccessor<AppDatabase> with _$CoachDaoMixin {
  CoachDao(super.db);

  Future<CoachConversation?> getActiveConversation(String userId) =>
      (select(coachConversations)
            ..where((c) => c.userId.equals(userId))
            ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<String> createConversation(CoachConversationsCompanion conv) =>
      into(coachConversations).insert(conv).then((_) => conv.id.value);

  Stream<List<CoachMessage>> watchMessages(String conversationId, {int limit = 50}) =>
      (select(coachMessages)
            ..where((m) => m.conversationId.equals(conversationId))
            ..orderBy([(m) => OrderingTerm.asc(m.createdAt)])
            ..limit(limit))
          .watch();

  Future<void> insertMessage(CoachMessagesCompanion msg) =>
      into(coachMessages).insert(msg);

  Future<void> updateMessageRating(String messageId, bool rating) =>
      (update(coachMessages)..where((m) => m.id.equals(messageId)))
          .write(CoachMessagesCompanion(satisfactionRating: Value(rating)));

  Future<void> markChangeApplied(String messageId) =>
      (update(coachMessages)..where((m) => m.id.equals(messageId)))
          .write(const CoachMessagesCompanion(planChangeApplied: Value(true)));

  Future<CoachQuotaUsageData?> getQuota(String userId, String isoWeek) =>
      (select(coachQuotaUsage)
            ..where((q) => q.userId.equals(userId) & q.isoWeek.equals(isoWeek)))
          .getSingleOrNull();

  Future<void> upsertQuota(CoachQuotaUsageCompanion quota) =>
      into(coachQuotaUsage).insertOnConflictUpdate(quota);
}
