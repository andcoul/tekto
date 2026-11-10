import 'package:uuid/uuid.dart';

import '../../../shared/models/workout_model.dart';
import '../../../shared/services/local_db/database.dart';
import '../../../shared/services/local_db/daos/workout_dao.dart';
import '../../../shared/services/sync/sync_queue.dart';

const _uuid = Uuid();

/// WorkoutLogRepository — offline-first (Principle I).
/// All writes go to Drift first, then enqueue to SyncQueue.
class WorkoutLogRepository {
  WorkoutLogRepository({
    required AppDatabase db,
    required SyncQueue syncQueue,
    required String userId,
  })  : _workoutDao = WorkoutDao(db),
        _syncQueue = syncQueue,
        _userId = userId;

  final WorkoutDao _workoutDao;
  final SyncQueue _syncQueue;
  final String _userId;

  Future<String> startWorkout(String sessionId) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _workoutDao.startWorkout(WorkoutLogsCompanion.insert(
      id: id,
      userId: _userId,
      sessionId: sessionId,
    ));

    await _syncQueue.enqueue(
      operation: 'INSERT',
      tableName: 'workout_logs',
      payload: {
        'id': id,
        'user_id': _userId,
        'session_id': sessionId,
        'started_at': now.toIso8601String(),
      },
    );

    return id;
  }

  Future<void> finishWorkout(
    String logId, {
    required int effortRating,
    required double totalVolumeKg,
  }) async {
    await _workoutDao.finishWorkout(logId, effortRating, totalVolumeKg);

    await _syncQueue.enqueue(
      operation: 'UPDATE',
      tableName: 'workout_logs',
      payload: {
        'id': logId,
        'finished_at': DateTime.now().toIso8601String(),
        'effort_rating': effortRating,
        'total_volume_kg': totalVolumeKg,
      },
    );
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
