import 'package:freezed_annotation/freezed_annotation.dart';

part 'subscription_model.freezed.dart';
part 'subscription_model.g.dart';

@freezed
class SubscriptionModel with _$SubscriptionModel {
  const factory SubscriptionModel({
    required String id,
    required String userId,
    required String tier,
    required bool isTrial,
    DateTime? trialEndsAt,
    DateTime? currentPeriodEndsAt,
    DateTime? cancelledAt,
    String? revenuecatCustomerId,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SubscriptionModel;

  const SubscriptionModel._();

  bool get isPro {
    if (tier != 'pro') return false;
    final now = DateTime.now();
    if (isTrial && trialEndsAt != null) return trialEndsAt!.isAfter(now);
    if (currentPeriodEndsAt != null) return currentPeriodEndsAt!.isAfter(now);
    return false;
  }

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionModelFromJson(json);
}

@freezed
class FormCheckSessionModel with _$FormCheckSessionModel {
  const factory FormCheckSessionModel({
    required String id,
    required String userId,
    required String exerciseSlug,
    String? workoutLogId,
    required int repCount,
    int? formScore,
    required List<String> cuesShown,
    String? topTipEn,
    String? topTipFr,
    required bool userShared, // always false unless user explicitly shares
    required DateTime createdAt,
  }) = _FormCheckSessionModel;

  factory FormCheckSessionModel.fromJson(Map<String, dynamic> json) =>
      _$FormCheckSessionModelFromJson(json);
}
