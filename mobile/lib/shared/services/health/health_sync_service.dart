import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:health/health.dart';

import '../local_db/database.dart';
import '../sync/sync_queue.dart';

/// The two Health calls Tekto makes; [PluginHealthPlatform] in the app, a fake in tests.
abstract class HealthPlatform {
  Future<bool> requestAuthorization();
  Future<bool> writeStrengthWorkout({required DateTime start, required DateTime end});
}

/// Apple HealthKit (iOS) / Google Health Connect (Android) via the `health` plugin.
class PluginHealthPlatform implements HealthPlatform {
  PluginHealthPlatform([Health? health]) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  static const _types = [HealthDataType.WORKOUT];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> requestAuthorization() async {
    await _configure();
    return _health.requestAuthorization(_types, permissions: const [HealthDataAccess.WRITE]);
  }

  /// Writes the workout's real time window only. Tekto does not measure energy, so it
  /// writes none rather than an invented calorie figure.
  @override
  Future<bool> writeStrengthWorkout({required DateTime start, required DateTime end}) async {
    await _configure();
    return _health.writeWorkoutData(
      // HealthKit and Health Connect name the same activity differently.
      activityType: Platform.isIOS
          ? HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING
          : HealthWorkoutActivityType.STRENGTH_TRAINING,
      start: start,
      end: end,
      title: 'Tekto',
    );
  }
}

/// Writes finished workouts to Health when the user opted in (`users.health_sync_enabled`,
/// Constitution II). Never throws and never waits longer than [timeout], so finishing a
/// workout is never blocked by the Health API (FR-012).
class HealthSyncService {
  HealthSyncService({
    required HealthPlatform platform,
    required AppDatabase db,
    required SyncQueue syncQueue,
    this.timeout = const Duration(seconds: 10),
  })  : _platform = platform,
        _db = db,
        _syncQueue = syncQueue;

  final HealthPlatform _platform;
  final AppDatabase _db;
  final SyncQueue _syncQueue;
  final Duration timeout;

  /// Returns true when the workout was written to Health and `synced_to_health` was set.
  Future<bool> syncFinishedWorkout({
    required String workoutLogId,
    required bool healthSyncEnabled,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!healthSyncEnabled) return false;
    try {
      final written = await () async {
        if (!await _platform.requestAuthorization()) return false;
        return _platform.writeStrengthWorkout(start: start, end: end);
      }()
          .timeout(timeout);
      if (!written) return false;

      await (_db.update(_db.workoutLogs)..where((w) => w.id.equals(workoutLogId)))
          .write(const WorkoutLogsCompanion(syncedToHealth: Value(true)));
      await _syncQueue.enqueue(
        operation: 'update',
        tableName: 'workout_logs',
        payload: {'id': workoutLogId, 'synced_to_health': true},
      );
      return true;
    } on Object {
      // Health unavailable, permission sheet dismissed, timeout: the workout is already saved.
      return false;
    }
  }
}
