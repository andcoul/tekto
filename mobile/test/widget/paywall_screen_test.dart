// T052 — paywall surface (FR-031, FR-032, Constitution V), written before the PaywallScreen rewrite.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/subscription/domain/pro_offers.dart';
import 'package:tekto/features/subscription/ui/paywall_screen.dart';

const storePrices = [
  ProOffer(isAnnual: true, priceString: '79,99 €', price: 79.99),
  ProOffer(isAnnual: false, priceString: '12,99 €', price: 12.99),
];

Future<List<ProOffer>> pump(WidgetTester tester, {List<ProOffer>? offers = storePrices, bool online = true,
    PaywallFeature feature = PaywallFeature.coach, Future<void> Function()? onPurchase}) async {
  final purchased = <ProOffer>[];
  final router = GoRouter(initialLocation: '/home', routes: [
    GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
    GoRoute(path: '/paywall', builder: (_, __) => PaywallScreen(feature: feature)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      proOffersProvider.overrideWith((ref) async => offers),
      isOnlineProvider.overrideWith((ref) => Stream.value(online)),
      proPurchaseProvider.overrideWithValue((offer) async {
        purchased.add(offer);
        await onPurchase?.call();
      }),
      proRestoreProvider.overrideWithValue(() async {}),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  router.push('/paywall');
  await tester.pumpAndSettle();
  return purchased;
}

Finder trialButton() => find.widgetWithText(ElevatedButton, 'Start 7-day free trial');

void main() {
  testWidgets('Restore purchases and cancel-anytime are always visible (offers, no offers, offline)', (tester) async {
    for (final (offers, online) in [(storePrices, true), (null, true), (storePrices, false)]) {
      await pump(tester, offers: offers, online: online);
      expect(find.text('Restore purchases'), findsOneWidget, reason: 'offers=$offers online=$online');
      expect(find.text('Cancel anytime'), findsOneWidget, reason: 'offers=$offers online=$online');
    }
  });

  testWidgets('prices come from the store; annual is selected by default; savings computed from store prices', (tester) async {
    await pump(tester);
    expect(find.text('79,99 €'), findsOneWidget);
    expect(find.text('12,99 €'), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.text('Save 49%'), findsOneWidget);
    final annual = tester.widget<RadioListTile<bool>>(find.byWidgetPredicate((w) => w is RadioListTile<bool> && w.value));
    expect(annual.groupValue, isTrue);
  });

  testWidgets('starting the trial buys the selected package and closes the paywall', (tester) async {
    final purchased = await pump(tester);
    await tester.ensureVisible(trialButton());
    await tester.tap(trialButton());
    await tester.pumpAndSettle();
    expect(purchased.single.isAnnual, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('no offers in this storefront: purchase hidden, region message, restore kept', (tester) async {
    await pump(tester, offers: null);
    expect(find.text('Tekto Pro is not yet available in your region.'), findsOneWidget);
    expect(trialButton(), findsNothing);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('offline: purchase and restore disabled with a message; the value video still shows', (tester) async {
    await pump(tester, online: false);
    expect(find.text('Connect to the internet to start your trial.'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(trialButton()).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Restore purchases')).onPressed, isNull);
    expect(find.byType(PaywallValueVideo), findsOneWidget);
  });

  testWidgets('the value video is the one for the feature that opened the paywall', (tester) async {
    for (final f in PaywallFeature.values) {
      await pump(tester, feature: f);
      expect(tester.widget<PaywallValueVideo>(find.byType(PaywallValueVideo)).feature, f);
    }
    expect(PaywallFeature.formCheck.clipAsset, 'assets/video/paywall_form_check.mp4');
  });
}
