import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../shared/services/local_db/daos/subscription_dao.dart';
import '../../../shared/services/local_db/database.dart';
import '../data/subscription_repository.dart';

/// Whether the user has Pro right now, and when it ends.
class EntitlementState {
  const EntitlementState({required this.isPro, required this.isTrial, this.periodEndsAt});

  final bool isPro;

  /// True only while a trial is active.
  final bool isTrial;

  /// End of the active trial or billing period.
  final DateTime? periodEndsAt;

  static const free = EntitlementState(isPro: false, isTrial: false);
}

/// Entitlement rule (data-model subscriptions; T057). When the server row exists it decides:
/// `tier == 'pro' AND (period active OR active trial)`; an expired trial is free. RevenueCat's
/// cache is used only before the webhook has created the row (e.g. seconds after a purchase).
EntitlementState resolveEntitlement({required Subscription? server, bool? revenueCatIsPro, required DateTime now}) {
  if (server == null) {
    return (revenueCatIsPro ?? false) ? const EntitlementState(isPro: true, isTrial: false) : EntitlementState.free;
  }
  final isPro = SubscriptionDao.isProRow(server, now: now);
  if (!isPro) return EntitlementState.free;
  final trialActive = server.isTrial && (server.trialEndsAt?.isAfter(now) ?? false);
  return EntitlementState(
    isPro: true,
    isTrial: trialActive,
    periodEndsAt: trialActive ? server.trialEndsAt : server.currentPeriodEndsAt,
  );
}

/// The signed-in user's entitlement, from the device cache of `subscriptions` (works offline).
/// The cache is refreshed from the server on start and whenever RevenueCat reports a change.
final entitlementProvider = StreamProvider<EntitlementState>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(EntitlementState.free);
  final repo = ref.watch(subscriptionRepositoryProvider);
  final revenueCat = ref.watch(revenueCatServiceProvider);
  final clock = ref.watch(clockProvider);

  unawaited(repo.refreshFromServer(userId));
  final changes = revenueCat.customerInfoStream.listen((_) => unawaited(repo.refreshFromServer(userId)));
  ref.onDispose(changes.cancel);

  return repo.watchRow(userId).asyncMap((row) async => resolveEntitlement(
        server: row,
        revenueCatIsPro: row == null ? await revenueCat.isPro() : null,
        now: clock(),
      ));
});
