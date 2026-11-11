import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/models/workout_model.dart';
import '../../../shared/services/local_db/database.dart';
import '../../../shared/services/local_db/daos/workout_dao.dart';
import '../../../shared/services/sync/sync_queue.dart';

const _uuid = Uuid();

/// WorkoutLogRepository — offline-first (Principle I).
/// All writes go to Drift first, then enqueue to SyncQueue. Timestamps are sent in
/// UTC so the server's `timestamptz` columns (and the FR-026 week boundary) are exact.
class WorkoutLogRepository {
  WorkoutLogRepository({
    required AppDatabase db,
    required SyncQueue syncQueue,
    required String userId,
    DateTime Function() clock = DateTime.now,
  })  : _workoutDao = WorkoutDao(db),
        _syncQueue = syncQueue,
        _userId = userId,
        _clock = clock;

  final WorkoutDao _workoutDao;
  final SyncQueue _syncQueue;
  final String _userId;
  final DateTime Function() _clock;

  Future<String> startWorkout(String sessionId) async {
    final id = _uuid.v4();
    final now = _clock();

    await _workoutDao.startWorkout(WorkoutLogsCompanion.insert(
      id: id,
      userId: _userId,
      sessionId: sessionId,
      startedAt: Value(now),
    ));

    await _syncQueue.enqueue(
      operation: 'insert',
      tableName: 'workout_logs',
      payload: {
        'id': id,
        'user_id': _userId,
        'session_id': sessionId,
        'started_at': now.toUtc().toIso8601String(),
      },
    );

    return id;
  }

  /// Marks the workout finished and returns the finish time.
  Future<DateTime> finishWorkout(
    String logId, {
    required int effortRating,
    required double totalVolumeKg,
  }) async {
    final now = _clock();
    await _workoutDao.finishWorkout(logId, effortRating, totalVolumeKg, finishedAt: now);

    await _syncQueue.enqueue(
      operation: 'update',
      tableName: 'workout_logs',
      payload: {
        'id': logId,
        'finished_at': now.toUtc().toIso8601String(),
        'effort_rating': effortRating,
        'total_volume_kg': totalVolumeKg,
      },
    );
    return now;
  }

  Future<WorkoutLogModel?> getActiveLog() async {
    final row = await _workoutDao.getActiveLog(_userId);
    if (row == null) return null;
    return _toModel(row);
  }

  Future<List<WorkoutLogModel>> getHistory({int limit = 20}) async {
    final rows = await _workoutDao.getHistory(_userId, limit: limit);
    return rows.map(_toModel).toList();
  }

  static WorkoutLogModel _toModel(WorkoutLog w) => WorkoutLogModel(
        id: w.id,
        userId: w.userId,
        sessionId: w.sessionId,
        startedAt: w.startedAt,
        finishedAt: w.finishedAt,
        effortRating: w.effortRating,
        totalVolumeKg: w.totalVolumeKg,
        syncedToHealth: w.syncedToHealth,
        createdAt: w.createdAt,
      );
}
