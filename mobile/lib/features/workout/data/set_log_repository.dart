import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/local_db/database.dart';
import '../../../shared/services/local_db/daos/workout_dao.dart';
import '../../../shared/services/sync/sync_queue.dart';
import '../domain/live_session.dart';
import '../domain/pr_detection_service.dart';

const _uuid = Uuid();

/// Saves sets to the device first and queues them for sync (Constitution I).
class SetLogRepository {
  SetLogRepository({
    required AppDatabase db,
    required SyncQueue syncQueue,
    DateTime Function() clock = DateTime.now,
  })  : _workoutDao = WorkoutDao(db),
        _syncQueue = syncQueue,
        _clock = clock,
        _prService = const PRDetectionService();

  final WorkoutDao _workoutDao;
  final SyncQueue _syncQueue;
  final DateTime Function() _clock;
  final PRDetectionService _prService;

  /// Saves one set and returns it with `isPr` decided against the local record,
  /// using the same formula as the server trigger (FR-010).
  Future<LoggedSet> logSet({
    required String workoutLogId,
    required String planExerciseId,
    required String exerciseSlug,
    required int setNumber,
    required double weightKg,
    required int reps,
    double? rpeActual,
    String? userId,
  }) async {
    final currentPr = userId == null ? null : await _workoutDao.getPr(userId, exerciseSlug);
    final isPr = _prService.isPR(weightKg: weightKg, reps: reps, currentBestE1rm: currentPr?.bestE1rm);

    final id = _uuid.v4();
    final now = _clock();

    await _workoutDao.insertSetLog(SetLogsCompanion.insert(
      id: id,
      workoutLogId: workoutLogId,
      planExerciseId: planExerciseId,
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      rpeActual: Value(rpeActual),
      isPr: Value(isPr),
      loggedAt: Value(now),
    ));

    // Keep the local record current so the next set compares against it offline.
    // The server keeps its own copy via the `update_personal_record()` trigger.
    if (isPr && userId != null) {
      await _workoutDao.upsertPr(PersonalRecordsCompanion.insert(
        id: currentPr?.id ?? _uuid.v4(),
        userId: userId,
        exerciseSlug: exerciseSlug,
        bestWeightKg: weightKg,
        bestReps: reps,
        bestE1rm: _prService.compute(weightKg: weightKg, reps: reps),
        achievedAt: Value(now),
      ));
    }

    await _syncQueue.enqueue(
      operation: 'insert',
      tableName: 'set_logs',
      payload: {
        'id': id,
        'workout_log_id': workoutLogId,
        'plan_exercise_id': planExerciseId,
        'set_number': setNumber,
        'weight_kg': weightKg,
        'reps': reps,
        'rpe_actual': rpeActual,
        'logged_at': now.toUtc().toIso8601String(),
      },
    );

    return LoggedSet(
      id: id,
      planExerciseId: planExerciseId,
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      rpe: rpeActual,
      isPr: isPr,
    );
  }
}
