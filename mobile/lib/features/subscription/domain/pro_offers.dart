import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di/providers.dart';

part 'pro_offers.g.dart';

/// One purchasable Pro option with its store-localized price (FR-032 — never hard-coded).
class ProOffer {
  const ProOffer({required this.isAnnual, required this.priceString, this.price, this.package});
  final bool isAnnual;

  /// Numeric store price in the storefront currency, for the savings label only.
  final double? price;

  /// Localized price from the App Store / Play storefront, e.g. "79,99 €".
  final String priceString;

  /// RevenueCat package to purchase; null in tests.
  final Package? package;
}

/// Buys a Pro offer through the store; throws when the purchase fails or is cancelled.
typedef ProPurchase = Future<void> Function(ProOffer offer);

/// Restores previous purchases; throws when the store is unreachable.
typedef ProRestore = Future<void> Function();

/// Store restore seam: the default restores through RevenueCat; widget tests override it.
@riverpod
ProRestore proRestore(Ref ref) => () async {
      await ref.read(revenueCatServiceProvider).restorePurchases();
    };

/// Annual saving versus 12 monthly payments, in whole percent, from the store prices of this
/// storefront (FR-032); null when either price is unknown or there is no saving.
int? annualSavingsPercent(List<ProOffer> offers) {
  final annual = offers.where((o) => o.isAnnual).firstOrNull?.price;
  final monthly = offers.where((o) => !o.isAnnual).firstOrNull?.price;
  if (annual == null || monthly == null || monthly <= 0) return null;
  final saving = (1 - annual / (monthly * 12)) * 100;
  return saving >= 1 ? saving.round() : null;
}

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
    if (current.annual case final annual?)
      ProOffer(
          isAnnual: true,
          priceString: annual.storeProduct.priceString,
          price: annual.storeProduct.price,
          package: annual),
    if (current.monthly case final monthly?)
      ProOffer(
          isAnnual: false,
          priceString: monthly.storeProduct.priceString,
          price: monthly.storeProduct.price,
          package: monthly),
  ];
  return offers.isEmpty ? null : offers;
}
