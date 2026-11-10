import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise_model.freezed.dart';
part 'exercise_model.g.dart';

@freezed
abstract class ExerciseModel with _$ExerciseModel {
  const factory ExerciseModel({
    required String slug,
    required String nameEn,
    required String nameFr,
    required List<String> equipment,
    required List<String> musclePrimary,
    required List<String> muscleSecondary,
    required List<String> cuesEn,
    required List<String> cuesFr,
    required List<String> commonMistakesEn,
    required List<String> commonMistakesFr,
    String? videoFrontUrl,
    String? videoSideUrl,
    @Default(10) int videoDurationSec,
    String? captionsEnUrl,
    String? captionsFrUrl,
    /// Limitation tags that exclude this exercise from plans and swaps.
    @Default([]) List<String> contraindications,
    String? variationEasierSlug,
    String? variationHarderSlug,
    required bool formCheckSupported,
    String? formCheckLiftKey,
  }) = _ExerciseModel;

  factory ExerciseModel.fromJson(Map<String, dynamic> json) =>
      _$ExerciseModelFromJson(json);
}
