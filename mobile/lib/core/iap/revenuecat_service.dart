import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Wraps the RevenueCat SDK for cross-platform IAP (iOS App Store + Google Play).
class RevenueCatService {
  Future<void> initialize(String userId) async {
    final apiKey = Platform.isIOS
        ? const String.fromEnvironment('REVENUECAT_API_KEY_IOS')
        : const String.fromEnvironment('REVENUECAT_API_KEY_ANDROID');

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

    final config = PurchasesConfiguration(apiKey)..appUserID = userId;
    await Purchases.configure(config);
  }

  /// Fetches current entitlement state from RevenueCat.
  Future<bool> isPro() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey('pro');
    } catch (_) {
      return false;
    }
  }

  /// Returns all available offerings (monthly + annual plans with trial).
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Purchases the specified package. Throws [PurchasesErrorCode] on failure.
  Future<CustomerInfo> purchasePackage(Package package) =>
      Purchases.purchasePackage(package);

  /// Restores previous purchases. Use after account sign-in on a new device.
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  /// Stream of CustomerInfo updates (entitlement state changes).
  Stream<CustomerInfo> get customerInfoStream =>
      Purchases.customerInfoStream;
}
