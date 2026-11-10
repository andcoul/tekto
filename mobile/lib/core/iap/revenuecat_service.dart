import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Wraps the RevenueCat SDK for cross-platform IAP (iOS App Store + Google Play).
///
/// [identify] must be called with the Supabase `auth.uid()` after sign-in so RevenueCat's
/// customer ID matches `subscriptions.user_id` (contracts/ai-services.md §4).
class RevenueCatService {
  bool _configured = false;
  final _customerInfo = StreamController<CustomerInfo>.broadcast();

  /// Configures the SDK on first sign-in, then switches customers with `logIn`.
  Future<void> identify(String userId) async {
    if (!_configured) {
      final apiKey = Platform.isIOS
          ? const String.fromEnvironment('REVENUECAT_API_KEY_IOS')
          : const String.fromEnvironment('REVENUECAT_API_KEY_ANDROID');
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
      await Purchases.configure(PurchasesConfiguration(apiKey)..appUserID = userId);
      Purchases.addCustomerInfoUpdateListener(_customerInfo.add);
      _configured = true;
      return;
    }
    await Purchases.logIn(userId);
  }

  /// Call on sign-out so the next user does not inherit entitlements.
  Future<void> reset() async {
    if (_configured) await Purchases.logOut();
  }

  /// Current customer info, or null when the SDK is not configured or unreachable.
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_configured) return null;
    try {
      return await Purchases.getCustomerInfo();
    } on PlatformException {
      return null;
    }
  }

  /// RevenueCat's view of the Pro entitlement (the server `subscriptions.tier` is authoritative).
  Future<bool> isPro() async {
    final info = await getCustomerInfo();
    return info?.entitlements.active.containsKey('pro') ?? false;
  }

  /// Available offerings (monthly + annual with trial); null if unavailable in this storefront.
  Future<Offerings?> getOfferings() async {
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings();
    } on PlatformException {
      return null;
    }
  }

  /// Purchases [package]. Throws [PlatformException] on failure or cancellation.
  Future<CustomerInfo> purchasePackage(Package package) async =>
      (await Purchases.purchasePackage(package)).customerInfo;

  /// Restores previous purchases (new device or reinstall).
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  /// Entitlement changes pushed by the SDK.
  Stream<CustomerInfo> get customerInfoStream => _customerInfo.stream;
}
