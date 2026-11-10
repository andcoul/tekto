/// PRDetectionService — business logic for personal record detection.
/// Principle V: unit tested in mobile/test/unit/pr_detection_service_test.dart
///
/// e1RM formula: weight × (1 + reps / 30.0)
/// A PR is detected when the new e1RM exceeds the stored best.
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

  /// Computes the estimated one-rep max using the Epley formula.
  double compute({required double weightKg, required int reps}) {
    if (reps <= 0) return 0;
    if (reps == 1) return weightKg;
    return weightKg * (1.0 + reps / 30.0);
  }
}
