import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:tekto/core/di/providers.dart';
import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/services/local_db/daos/coach_dao.dart';
import 'package:tekto/shared/services/local_db/database.dart';

const _uuid = Uuid();

/// Manages coach conversations (the top-level thread container).
class CoachConversationRepository {
  const CoachConversationRepository({required CoachDao dao, DateTime Function() clock = DateTime.now})
      : _dao = dao,
        _clock = clock;

  final CoachDao _dao;
  final DateTime Function() _clock;

  /// Returns the user's most recent conversation, creating one if none exists.
  Future<CoachConversationModel> getOrCreateActiveConversation(String userId) async {
    final existing = await _dao.getActiveConversation(userId);
    if (existing != null) return toModel(existing);

    final now = _clock();
    final created = CoachConversationModel(id: _uuid.v4(), userId: userId, createdAt: now, updatedAt: now);
    await _dao.createConversation(CoachConversationsCompanion.insert(
      id: created.id,
      userId: userId,
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return created;
  }

  static CoachConversationModel toModel(CoachConversation row) => CoachConversationModel(
        id: row.id,
        userId: row.userId,
        planId: row.planId,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}

final coachConversationRepositoryProvider = Provider<CoachConversationRepository>(
  (ref) => CoachConversationRepository(
    dao: CoachDao(ref.watch(appDatabaseProvider)),
    clock: ref.watch(clockProvider),
  ),
);
