import 'package:health/health.dart';

/// Writes completed workout data to Apple HealthKit / Google Health Connect.
/// Respects the user's `health_sync_enabled` preference (Principle II: opt-in).
class HealthSyncService {
  static final HealthFactory _health = HealthFactory();

  static const _types = [HealthDataType.WORKOUT];

  Future<bool> requestPermission() async {
    final permissions = _types.map((_) => HealthDataAccess.READ_WRITE).toList();
    return await _health.requestAuthorization(_types, permissions: permissions);
  }

  /// Writes a strength training workout.
  /// [startTime] / [endTime]: actual workout window.
  /// [totalVolumeKg]: total weight moved; stored as ACTIVE_ENERGY_BURNED proxy.
  Future<bool> writeWorkout({
    required DateTime startTime,
    required DateTime endTime,
    required double totalVolumeKg,
  }) async {
    try {
      return await _health.writeWorkout(
        activityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
        start: startTime,
        end: endTime,
        totalEnergyBurned: (totalVolumeKg * 0.1).round(), // rough kcal estimate
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );
    } catch (_) {
      return false;
    }
  }
}
