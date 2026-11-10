import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/shared/models/subscription_model.dart';
import 'package:tekto/shared/services/local_db/daos/subscription_dao.dart';

/// Reads the user's subscription state.
///
/// Source of truth: Supabase `subscriptions` table (written by the RevenueCat
/// webhook). The local Drift cache is kept in sync for offline access.
///
/// `isPro` = tier == 'pro' AND the period has not yet expired, OR an active
/// trial period is still running.
class SubscriptionRepository {
  const SubscriptionRepository({
    required SubscriptionDao subscriptionDao,
  }) : _dao = subscriptionDao;

  final SubscriptionDao _dao;

  /// Stream of the current user's subscription, updated whenever the DB row
  /// changes.
  Stream<SubscriptionModel?> watchSubscription(String userId) =>
      _dao.watchForUser(userId);

  /// Returns true when the current subscription grants Pro entitlement.
  Future<bool> isPro(String userId) async {
    final sub = await _dao.getForUser(userId);
    if (sub == null) return false;
    return _isPro(sub);
  }

  /// Upsert a subscription record — called by the entitlement provider when
  /// RevenueCat SDK reports a customer-info update.
  Future<void> upsert(SubscriptionModel model) => _dao.upsert(model);

  static bool _isPro(SubscriptionModel s) {
    if (s.tier != 'pro') return false;
    final now = DateTime.now();
    if (s.isTrial && s.trialEndsAt != null) {
      return s.trialEndsAt!.isAfter(now);
    }
    if (s.currentPeriodEndsAt != null) {
      return s.currentPeriodEndsAt!.isAfter(now);
    }
    return false;
  }
}

/// Riverpod provider — resolved in `core/di/providers.dart`.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
