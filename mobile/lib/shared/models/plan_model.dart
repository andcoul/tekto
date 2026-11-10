import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_model.freezed.dart';
part 'plan_model.g.dart';

@freezed
abstract class PlanModel with _$PlanModel {
  const factory PlanModel({
    required String id,
    required String userId,
    required String name,
    required String status,
    required int weeksTotal,
    required int currentWeek,
    /// Monday in the user's time zone; week N = startDate + 7·(N−1) … +6.
    required DateTime startDate,
    @Default(0) int lastAdaptedWeek,
    /// 'ai' | 'template' | 'template_fallback'
    required String source,
    String? templateSlug,
    /// Deprecated: superseded by [source] / [templateSlug].
    String? generatedBy,
    String? rationaleEn,
    String? rationaleFr,
    @Default([]) List<Map<String, dynamic>> adaptationLog,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _PlanModel;

  factory PlanModel.fromJson(Map<String, dynamic> json) =>
      _$PlanModelFromJson(json);
}

@freezed
abstract class SessionModel with _$SessionModel {
  const factory SessionModel({
    required String id,
    required String planId,
    required int weekNumber,
    required int dayOfWeek,
    required String nameEn,
    required String nameFr,
    required List<String> muscleGroups,
    int? estimatedMin,
    required DateTime createdAt,
  }) = _SessionModel;

  factory SessionModel.fromJson(Map<String, dynamic> json) =>
      _$SessionModelFromJson(json);
}

@freezed
abstract class PlanExerciseModel with _$PlanExerciseModel {
  const factory PlanExerciseModel({
    required String id,
    required String sessionId,
    required String exerciseSlug,
    required int sortOrder,
    required int sets,
    required int repsMin,
    required int repsMax,
    double? rpeTarget,
    required int restSec,
    double? suggestedWeightKg,
  }) = _PlanExerciseModel;

  factory PlanExerciseModel.fromJson(Map<String, dynamic> json) =>
      _$PlanExerciseModelFromJson(json);
}
