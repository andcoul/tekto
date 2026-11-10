import 'package:tekto/shared/models/subscription_model.dart';
import 'package:tekto/shared/services/form_check/form_score_calculator.dart';
import 'package:tekto/shared/services/local_db/daos/form_check_dao.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

/// Saves form check session results to the local Drift DB and syncs via queue.
///
/// user_shared defaults to false (Principle II).
class FormCheckRepository {
  const FormCheckRepository({
    required FormCheckDao dao,
    required SyncQueue syncQueue,
    required String userId,
  })  : _dao = dao,
        _syncQueue = syncQueue,
        _userId = userId;

  final FormCheckDao _dao;
  final SyncQueue _syncQueue;
  final String _userId;

  /// Persists a completed form check session.
  ///
  /// Returns the created [FormCheckSessionModel].
  Future<FormCheckSessionModel> saveSession({
    required String exerciseSlug,
    required FormSetSummary summary,
  }) async {
    final session = FormCheckSessionModel(
      id: _uuid(),
      userId: _userId,
      exerciseSlug: exerciseSlug,
      repCount: summary.repCount,
      formScore: summary.score,
      cuesShown: summary.cuesShown,
      topTipEn: summary.topTipEn,
      topTipFr: summary.topTipFr,
      userShared: false, // Privacy default — Principle II
      createdAt: DateTime.now(),
    );

    await _dao.insertSession(session);

    // Enqueue for server sync
    await _syncQueue.enqueue(
      table: 'form_check_sessions',
      operation: 'INSERT',
      payload: session.toJson(),
    );

    return session;
  }

  /// Stream of all form check sessions for the current user.
  Stream<List<FormCheckSessionModel>> watchSessions() =>
      _dao.watchForUser(_userId);

  static String _uuid() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);
}
