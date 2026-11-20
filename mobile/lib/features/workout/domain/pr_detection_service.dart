/// PRDetectionService — business logic for personal record detection.
/// Principle V: unit tested in mobile/test/unit/pr_detection_service_test.dart
///
/// e1RM formula: weight × (1 + reps / 30.0) for every rep count, identical to the
/// server trigger `update_personal_record()` (migration 005), so the badge shown
/// offline always matches the record stored after sync.
/// A PR is detected when the new e1RM exceeds the stored best. Sets at 0 kg
/// (bodyweight) never count.
class PRDetectionService {
  const PRDetectionService();

  /// Returns true if [weightKg] × [reps] produces a new estimated 1RM.
  /// [currentBestE1rm] is the user's existing record (null if no record exists).
  bool isPR({
    required double weightKg,
    required int reps,
    required double? currentBestE1rm,
  }) {
    if (reps <= 0 || weightKg <= 0) return false;
    final newE1rm = compute(weightKg: weightKg, reps: reps);
    if (currentBestE1rm == null) return true;
    return newE1rm > currentBestE1rm;
  }

  /// Estimated one-rep max (Epley). 0 for unloaded sets or zero reps.
  double compute({required double weightKg, required int reps}) {
    if (reps <= 0 || weightKg <= 0) return 0;
    return weightKg * (1.0 + reps / 30.0);
  }
}
