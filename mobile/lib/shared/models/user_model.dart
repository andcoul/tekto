import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Application profile (extends Supabase auth.users) — data-model.md entity 1.
@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    /// 'muscle' | 'strength' | 'fat_loss' | 'general_fitness'
    required String goal,
    /// 'beginner' | 'intermediate' | 'advanced'
    required String level,
    required int daysPerWeek,
    required int sessionLengthMin,
    required List<String> equipment,
    /// Tags from: knee, lower_back, shoulder, wrist, elbow, hip, ankle, neck.
    @Default([]) List<String> limitations,
    String? limitationsNote,
    @Default('en') String language,
    @Default('kg') String unit,
    /// IANA time zone; drives the training-week boundary.
    @Default('UTC') String timezone,
    @Default(false) bool healthSyncEnabled,
    DateTime? consentAt,
    String? consentVersion,
    /// {squat|bench_press|deadlift: {weightKg, reps}}; null when the strength check was skipped.
    Map<String, dynamic>? strengthEstimates,
    DateTime? onboardingCompletedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}
