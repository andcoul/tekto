import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di/providers.dart';

part 'pro_offers.g.dart';

/// One purchasable Pro option with its store-localized price (FR-032 — never hard-coded).
class ProOffer {
  const ProOffer({required this.isAnnual, required this.priceString, this.package});
  final bool isAnnual;

  /// Localized price from the App Store / Play storefront, e.g. "79,99 €".
  final String priceString;

  /// RevenueCat package to purchase; null in tests.
  final Package? package;
}

/// Buys a Pro offer through the store; throws when the purchase fails or is cancelled.
typedef ProPurchase = Future<void> Function(ProOffer offer);

/// Store purchase seam: the default buys through RevenueCat; widget tests override it.
@riverpod
ProPurchase proPurchase(Ref ref) => (offer) async {
      final package = offer.package;
      if (package == null) throw StateError('Offer has no store package');
      await ref.read(revenueCatServiceProvider).purchasePackage(package);
    };

/// Pro offers in the current storefront, annual first; null when Pro is not sold there
/// (paywalls then hide purchase buttons but keep Restore — contracts/ai-services.md §4).
@riverpod
Future<List<ProOffer>?> proOffers(Ref ref) async {
  final offerings = await ref.read(revenueCatServiceProvider).getOfferings();
  final current = offerings?.current;
  if (current == null) return null;
  final offers = [
    if (current.annual case final annual?) ProOffer(isAnnual: true, priceString: annual.storeProduct.priceString, package: annual),
    if (current.monthly case final monthly?) ProOffer(isAnnual: false, priceString: monthly.storeProduct.priceString, package: monthly),
  ];
  return offers.isEmpty ? null : offers;
}
