import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/services/local_db/daos/coach_dao.dart';

/// Manages coach conversations (the top-level thread container).
class CoachConversationRepository {
  const CoachConversationRepository({required CoachDao dao}) : _dao = dao;

  final CoachDao _dao;

  /// Returns the active (most-recent open) conversation for [userId], creating
  /// one if none exists.
  Future<CoachConversationModel> getOrCreateActiveConversation(
      String userId) async {
    final existing = await _dao.getActiveConversation(userId);
    if (existing != null) return existing;

    final newConversation = CoachConversationModel(
      id: _uuid(),
      userId: userId,
      createdAt: DateTime.now(),
    );
    await _dao.insertConversation(newConversation);
    return newConversation;
  }

  /// Closes all open conversations (called when a new plan is generated).
  Future<void> archiveAll(String userId) =>
      _dao.archiveConversations(userId);

  static String _uuid() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);
}
