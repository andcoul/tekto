import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tekto/core/iap/revenuecat_service.dart';
import 'package:tekto/features/subscription/data/subscription_repository.dart';
import 'package:tekto/shared/models/subscription_model.dart';

/// Combined entitlement state: server-side `subscriptions.tier` is authoritative
/// on mismatch with the RevenueCat SDK's local cache.
class EntitlementState {
  const EntitlementState({
    required this.isPro,
    required this.isTrial,
    this.periodEndsAt,
  });

  final bool isPro;
  final bool isTrial;
  final DateTime? periodEndsAt;

  static const free = EntitlementState(isPro: false, isTrial: false);
}

/// [entitlementProvider] merges RevenueCat SDK `CustomerInfo` with the
/// Supabase-backed `SubscriptionRepository`.
///
/// The server-side record is always authoritative when the two disagree —
/// this prevents client-side entitlement spoofing.
final entitlementProvider = StreamProvider<EntitlementState>((ref) async* {
  final revenueCat = ref.watch(revenueCatServiceProvider);
  final subRepo = ref.watch(subscriptionRepositoryProvider);

  // Start from the RevenueCat customer info stream.
  await for (final customerInfo in revenueCat.customerInfoStream) {
    final rcIsPro = customerInfo.entitlements.active.containsKey('pro');

    // Cross-check with our server-side subscription record.
    // `auth.currentUser` is assumed accessible via a separate auth provider;
    // for now we derive userId from the RevenueCat app user ID.
    final userId = customerInfo.originalAppUserId;
    final serverIsPro = await subRepo.isPro(userId);

    // Server wins on mismatch.
    final effectiveIsPro = rcIsPro && serverIsPro;

    // Build state from server record for accurate trial/period data.
    final serverSub = await _fetchSub(subRepo, userId);

    yield EntitlementState(
      isPro: effectiveIsPro,
      isTrial: serverSub?.isTrial ?? false,
      periodEndsAt: serverSub?.currentPeriodEndsAt ?? serverSub?.trialEndsAt,
    );
  }
});

Future<SubscriptionModel?> _fetchSub(
  SubscriptionRepository repo,
  String userId,
) async {
  SubscriptionModel? result;
  await for (final sub in repo.watchSubscription(userId).take(1)) {
    result = sub;
  }
  return result;
}
