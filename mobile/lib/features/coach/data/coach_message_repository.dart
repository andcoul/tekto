import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/services/local_db/daos/coach_dao.dart';

/// Manages individual coach messages within a conversation.
class CoachMessageRepository {
  const CoachMessageRepository({required CoachDao dao}) : _dao = dao;

  final CoachDao _dao;

  /// Inserts a new message and returns it.
  Future<CoachMessageModel> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? screenContext,
  }) async {
    final message = CoachMessageModel(
      id: _uuid(),
      conversationId: conversationId,
      role: role,
      content: content,
      screenContext: screenContext,
      createdAt: DateTime.now(),
    );
    await _dao.insertMessage(message);
    return message;
  }

  /// Stream of messages for a conversation, oldest first.
  Stream<List<CoachMessageModel>> watchMessages(String conversationId) =>
      _dao.watchMessages(conversationId);

  /// Returns the [limit] most-recent messages (for context window injection).
  Future<List<CoachMessageModel>> getRecentMessages(
    String conversationId, {
    int limit = 10,
  }) =>
      _dao.getRecentMessages(conversationId, limit: limit);

  /// Marks a message's plan-change as applied.
  Future<void> markPlanChangeApplied(String messageId) =>
      _dao.markPlanChangeApplied(messageId);

  /// Records a satisfaction rating (thumbs up/down).
  Future<void> rateSatisfaction(String messageId, {required bool thumbsUp}) =>
      _dao.rateSatisfaction(messageId, thumbsUp: thumbsUp);

  static String _uuid() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);
}
