import '../../../shared/models/exercise_model.dart';

/// Exercises the user can swap [current] for (FR-028). Same rules as the server's
/// `swap-exercise` handler, so the sheet never offers a swap the server rejects: shares a primary
/// muscle, every equipment item is available (bodyweight always is), has a video
/// (Constitution IV) and no contraindication matches the user's limitations. Ranked by shared
/// primary muscles, then name.
List<ExerciseModel> swapAlternatives(
  List<ExerciseModel> library, {
  required ExerciseModel current,
  required List<String> equipment,
  required List<String> limitations,
}) {
  final available = {...equipment, 'bodyweight'};
  int shared(ExerciseModel e) => e.musclePrimary.where(current.musclePrimary.contains).length;
  final out = library
      .where((e) =>
          e.slug != current.slug &&
          shared(e) > 0 &&
          e.videoFrontUrl != null &&
          e.equipment.every(available.contains) &&
          !e.contraindications.any(limitations.contains))
      .toList()
    ..sort((a, b) {
      final byShared = shared(b).compareTo(shared(a));
      return byShared != 0 ? byShared : a.nameEn.compareTo(b.nameEn);
    });
  return out;
}
