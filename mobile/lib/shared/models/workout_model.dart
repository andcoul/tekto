import 'package:freezed_annotation/freezed_annotation.dart';

part 'workout_model.freezed.dart';
part 'workout_model.g.dart';

@freezed
abstract class WorkoutLogModel with _$WorkoutLogModel {
  const factory WorkoutLogModel({
    required String id,
    required String userId,
    required String sessionId,
    required DateTime startedAt,
    DateTime? finishedAt,
    int? effortRating,
    double? totalVolumeKg,
    required bool syncedToHealth,
    required DateTime createdAt,
  }) = _WorkoutLogModel;

  factory WorkoutLogModel.fromJson(Map<String, dynamic> json) =>
      _$WorkoutLogModelFromJson(json);
}

@freezed
abstract class SetLogModel with _$SetLogModel {
  const factory SetLogModel({
    required String id,
    required String workoutLogId,
    required String planExerciseId,
    required int setNumber,
    required double weightKg,
    required int reps,
    double? rpeActual,
    required bool isPr,
    required DateTime loggedAt,
  }) = _SetLogModel;

  factory SetLogModel.fromJson(Map<String, dynamic> json) =>
      _$SetLogModelFromJson(json);
}

@freezed
abstract class PersonalRecordModel with _$PersonalRecordModel {
  const factory PersonalRecordModel({
    required String id,
    required String userId,
    required String exerciseSlug,
    required double bestWeightKg,
    required int bestReps,
    required double bestE1rm,
    required DateTime achievedAt,
  }) = _PersonalRecordModel;

  factory PersonalRecordModel.fromJson(Map<String, dynamic> json) =>
      _$PersonalRecordModelFromJson(json);
}
