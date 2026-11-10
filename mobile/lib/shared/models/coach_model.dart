import 'package:freezed_annotation/freezed_annotation.dart';

part 'coach_model.freezed.dart';
part 'coach_model.g.dart';

@freezed
class CoachMessageModel with _$CoachMessageModel {
  const factory CoachMessageModel({
    required String id,
    required String conversationId,
    required String role, // 'user' | 'assistant' | 'system'
    required String content,
    String? contextScreen,
    String? contextExerciseSlug,
    Map<String, dynamic>? planChangeProposed,
    required bool planChangeApplied,
    bool? satisfactionRating,
    required DateTime createdAt,
  }) = _CoachMessageModel;

  factory CoachMessageModel.fromJson(Map<String, dynamic> json) =>
      _$CoachMessageModelFromJson(json);
}

@freezed
class CoachQuotaUsageModel with _$CoachQuotaUsageModel {
  const factory CoachQuotaUsageModel({
    required String userId,
    required String isoWeek,
    required int questionsUsed,
    required DateTime updatedAt,
  }) = _CoachQuotaUsageModel;

  factory CoachQuotaUsageModel.fromJson(Map<String, dynamic> json) =>
      _$CoachQuotaUsageModelFromJson(json);
}
