import 'package:freezed_annotation/freezed_annotation.dart';

part 'coach_model.freezed.dart';
part 'coach_model.g.dart';

@freezed
abstract class CoachConversationModel with _$CoachConversationModel {
  const factory CoachConversationModel({
    required String id,
    required String userId,
    String? planId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _CoachConversationModel;

  factory CoachConversationModel.fromJson(Map<String, dynamic> json) =>
      _$CoachConversationModelFromJson(json);
}

@freezed
abstract class CoachMessageModel with _$CoachMessageModel {
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
abstract class CoachQuotaUsageModel with _$CoachQuotaUsageModel {
  const factory CoachQuotaUsageModel({
    required String userId,
    required String isoWeek,
    required int questionsUsed,
    required DateTime updatedAt,
  }) = _CoachQuotaUsageModel;

  factory CoachQuotaUsageModel.fromJson(Map<String, dynamic> json) =>
      _$CoachQuotaUsageModelFromJson(json);
}
