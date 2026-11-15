import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../shared/services/form_check/form_score_calculator.dart';
import '../../../shared/services/local_db/daos/form_check_dao.dart';
import '../../../shared/services/local_db/database.dart';
import '../../../shared/services/sync/sync_queue.dart';
import '../domain/form_check_free_try_service.dart';

part 'form_check_repository.g.dart';

const _uuid = Uuid();

/// Saves form-check results locally and queues them for the server (Constitution I).
///
/// Only the summary is stored: no frames, images or landmarks (Constitution II).
/// `user_shared` is always false here; footage sharing is out of scope (FR-021).
class FormCheckRepository {
  FormCheckRepository({required AppDatabase db, required SyncQueue queue})
      : _dao = FormCheckDao(db),
        _queue = queue;

  final FormCheckDao _dao;
  final SyncQueue _queue;

  /// Persists a finished set and returns the new session id.
  /// [wasFreeTry] is true when a free user ran it under the one-try-per-lift rule (FR-029).
  Future<String> saveSession({
    required String userId,
    required String exerciseSlug,
    required FormSetSummary summary,
    required bool wasFreeTry,
    String? workoutLogId,
  }) async {
    final id = _uuid.v4();
    final createdAt = DateTime.now().toUtc();
    await _dao.insertSession(FormCheckSessionsCompanion.insert(
      id: id,
      userId: userId,
      exerciseSlug: exerciseSlug,
      workoutLogId: Value(workoutLogId),
      repCount: Value(summary.repCount),
      formScore: Value(summary.score),
      cuesShown: Value(jsonEncode(summary.cuesShown)),
      flaggedReps: Value(jsonEncode(summary.flaggedReps)),
      topTipEn: Value(summary.topTipEn),
      topTipFr: Value(summary.topTipFr),
      wasFreeTry: Value(wasFreeTry),
      userShared: const Value(false),
      createdAt: Value(createdAt),
    ));
    await _queue.enqueue(
      operation: 'insert',
      tableName: 'form_check_sessions',
      payload: {
        'id': id,
        'user_id': userId,
        'exercise_slug': exerciseSlug,
        'workout_log_id': workoutLogId,
        'rep_count': summary.repCount,
        'form_score': summary.score,
        'cues_shown': summary.cuesShown,
        'flagged_reps': summary.flaggedReps,
        'top_tip_en': summary.topTipEn,
        'top_tip_fr': summary.topTipFr,
        'was_free_try': wasFreeTry,
        'user_shared': false,
        'created_at': createdAt.toIso8601String(),
      },
    );
    return id;
  }
}

@riverpod
FormCheckRepository formCheckRepository(Ref ref) =>
    FormCheckRepository(db: ref.watch(appDatabaseProvider), queue: ref.watch(syncQueueProvider));

@riverpod
FormCheckFreeTryService formCheckFreeTryService(Ref ref) =>
    FormCheckFreeTryService(dao: FormCheckDao(ref.watch(appDatabaseProvider)));
