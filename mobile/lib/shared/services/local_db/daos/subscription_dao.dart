import 'package:drift/drift.dart';

import '../database.dart';

part 'subscription_dao.g.dart';

@DriftAccessor(tables: [Subscriptions])
class SubscriptionDao extends DatabaseAccessor<AppDatabase> with _$SubscriptionDaoMixin {
  SubscriptionDao(super.db);

  Future<Subscription?> getForUser(String userId) =>
      (select(subscriptions)..where((s) => s.userId.equals(userId))).getSingleOrNull();

  Stream<Subscription?> watchForUser(String userId) =>
      (select(subscriptions)..where((s) => s.userId.equals(userId))).watchSingleOrNull();

  Future<void> upsert(SubscriptionsCompanion sub) =>
      into(subscriptions).insertOnConflictUpdate(sub);

  /// data-model rule: `tier == 'pro' AND (current_period_ends_at > now() OR
  /// (is_trial AND trial_ends_at > now()))`.
  bool isPro(Subscription? sub, {DateTime? now}) {
    if (sub == null || sub.tier != 'pro') return false;
    final at = now ?? DateTime.now();
    final periodActive = sub.currentPeriodEndsAt?.isAfter(at) ?? false;
    final trialActive = sub.isTrial && (sub.trialEndsAt?.isAfter(at) ?? false);
    return periodActive || trialActive;
  }
}
