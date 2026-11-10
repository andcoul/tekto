// T033 — paywall surface (Constitution V), written before the TrialOfferScreen update.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/onboarding/ui/trial_offer_screen.dart';
import 'package:tekto/features/subscription/domain/pro_offers.dart';

Future<void> pump(WidgetTester tester, List<ProOffer>? offers) async {
  final router = GoRouter(initialLocation: '/onboarding/trial', routes: [
    GoRoute(path: '/onboarding/trial', builder: (_, __) => const TrialOfferScreen()),
    GoRoute(path: '/plan', builder: (_, __) => const Scaffold(body: Text('PLAN SCREEN'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [proOffersProvider.overrideWith((ref) async => offers)],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

const storePrices = [ProOffer(isAnnual: true, priceString: '79,99 €'), ProOffer(isAnnual: false, priceString: '12,99 €')];

void main() {
  testWidgets('prices come from the store, never hard-coded', (tester) async {
    await pump(tester, storePrices);
    expect(find.textContaining('79,99 €'), findsOneWidget);
    expect(find.textContaining('12,99 €'), findsOneWidget);
    expect(find.textContaining(r'$12.99'), findsNothing);
    expect(find.textContaining(r'$79.99'), findsNothing);
  });

  testWidgets('Restore purchases and cancel-anytime are always visible', (tester) async {
    for (final offers in [storePrices, null]) {
      await pump(tester, offers);
      expect(find.text('Restore purchases'), findsOneWidget, reason: 'offers: $offers');
      expect(find.textContaining('Cancel anytime'), findsOneWidget, reason: 'offers: $offers');
    }
  });

  testWidgets('"Skip for now" is always visible and leads to the plan', (tester) async {
    await pump(tester, storePrices);
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('PLAN SCREEN'), findsOneWidget);
  });

  testWidgets('no offers in this storefront: purchase hidden, region message, restore kept', (tester) async {
    await pump(tester, null);
    expect(find.text('Tekto Pro is not yet available in your region.'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsNothing);
    expect(find.text('Skip for now'), findsOneWidget);
  });
}
