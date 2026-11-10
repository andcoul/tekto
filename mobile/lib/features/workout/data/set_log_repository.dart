import 'package:uuid/uuid.dart';

import '../../../shared/models/workout_model.dart';
import '../../../shared/services/local_db/database.dart';
import '../../../shared/services/local_db/daos/workout_dao.dart';
import '../../../shared/services/sync/sync_queue.dart';
import '../domain/pr_detection_service.dart';

const _uuid = Uuid();

class SetLogRepository {
  SetLogRepository({
    required AppDatabase db,
    required SyncQueue syncQueue,
  })  : _workoutDao = WorkoutDao(db),
        _syncQueue = syncQueue,
        _prService = const PRDetectionService();

  final WorkoutDao _workoutDao;
  final SyncQueue _syncQueue;
  final PRDetectionService _prService;

  Future<SetLogModel> logSet({
    required String workoutLogId,
    required String planExerciseId,
    required String exerciseSlug,
    required int setNumber,
    required double weightKg,
    required int reps,
    double? rpeActual,
    String? userId,
  }) async {
    // Check for PR optimistically (before DB trigger)
    PersonalRecord? currentPr;
    if (userId != null) {
      currentPr = await _workoutDao.getPr(userId, exerciseSlug);
    }

    final isPr = _prService.isPR(
      weightKg: weightKg,
      reps: reps,
      currentBestE1rm: currentPr?.bestE1rm,
    );

    final id = _uuid.v4();
    final now = DateTime.now();

    await _workoutDao.insertSetLog(SetLogsCompanion.insert(
      id: id,
      workoutLogId: workoutLogId,
      planExerciseId: planExerciseId,
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      rpeActual: Value(rpeActual),
      isPr: Value(isPr),
    ));

    // Update local PR if applicable
    if (isPr && userId != null) {
      final newE1rm = _prService.compute(weightKg: weightKg, reps: reps);
      await _workoutDao.upsertPr(PersonalRecordsCompanion.insert(
        id: currentPr?.id ?? _uuid.v4(),
        userId: userId,
        exerciseSlug: exerciseSlug,
        bestWeightKg: weightKg,
        bestReps: reps,
        bestE1rm: newE1rm,
        achievedAt: Value(now),
      ));
    }

    await _syncQueue.enqueue(
      operation: 'INSERT',
      tableName: 'set_logs',
      payload: {
        'id': id,
        'workout_log_id': workoutLogId,
        'plan_exercise_id': planExerciseId,
        'set_number': setNumber,
        'weight_kg': weightKg,
        'reps': reps,
        'rpe_actual': rpeActual,
        'logged_at': now.toIso8601String(),
      },
    );

    return SetLogModel(
      id: id,
      workoutLogId: workoutLogId,
      planExerciseId: planExerciseId,
      setNumber: setNumber,
      weightKg: weightKg,
      reps: reps,
      rpeActual: rpeActual,
      isPr: isPr,
      loggedAt: now,
    );
  }

  Future<List<SetLogModel>> getSetsForLog(String workoutLogId) async {
    final rows = await _workoutDao.getSetsForLog(workoutLogId);
    return rows
        .map((s) => SetLogModel(
              id: s.id,
              workoutLogId: s.workoutLogId,
              planExerciseId: s.planExerciseId,
              setNumber: s.setNumber,
              weightKg: s.weightKg,
              reps: s.reps,
              rpeActual: s.rpeActual,
              isPr: s.isPr,
              loggedAt: s.loggedAt,
            ))
        .toList();
  }
}
