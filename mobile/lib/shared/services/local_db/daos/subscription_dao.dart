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

  /// True if the user has an active Pro subscription (not expired, not cancelled past period).
  bool isPro(Subscription? sub) {
    if (sub == null || sub.tier != 'pro') return false;
    final now = DateTime.now();
    if (sub.isTrial && sub.trialEndsAt != null) {
      return sub.trialEndsAt!.isAfter(now);
    }
    if (sub.currentPeriodEndsAt != null) {
      return sub.currentPeriodEndsAt!.isAfter(now);
    }
    return false;
  }
}
