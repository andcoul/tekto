// T033 — paywall surface (Constitution V), written before the TrialOfferScreen update.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/onboarding/domain/onboarding_controller.dart';
import 'package:tekto/features/onboarding/ui/plan_generation_screen.dart';
import 'package:tekto/features/onboarding/ui/trial_offer_screen.dart';
import 'package:tekto/features/subscription/domain/pro_offers.dart';

/// Records `generate-plan` calls; answers with [sources] in order (the last one repeats).
class FakeOnboardingApi implements OnboardingApi {
  FakeOnboardingApi({this.sources = const ['ai']});
  final List<String> sources;
  final List<bool> forceRegenerateCalls = [];

  @override
  Future<GeneratedPlanInfo> generatePlan({bool forceRegenerate = false}) async {
    forceRegenerateCalls.add(forceRegenerate);
    final source = sources[(forceRegenerateCalls.length - 1).clamp(0, sources.length - 1)];
    return GeneratedPlanInfo(
      planId: 'p2', source: source, fallbackNotice: source == 'template_fallback', notices: const [],
      rationaleEn: 'A 3-day full-body plan that fits your 45-minute sessions.',
      rationaleFr: 'Un programme full-body sur 3 jours adapté à vos séances de 45 minutes.',
    );
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {}

  @override
  Future<String> deviceTimezone() async => 'Europe/Paris';
}

Future<void> pump(WidgetTester tester, List<ProOffer>? offers, {FakeOnboardingApi? api, List<ProOffer>? purchased}) async {
  final router = GoRouter(initialLocation: '/onboarding/trial', routes: [
    GoRoute(path: '/onboarding/trial', builder: (_, __) => const TrialOfferScreen()),
    GoRoute(
      path: '/onboarding/generating',
      builder: (_, state) => PlanGenerationScreen(upgrade: state.uri.queryParameters['upgrade'] == '1'),
    ),
    GoRoute(path: '/plan', builder: (_, __) => const Scaffold(body: Text('PLAN SCREEN'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      proOffersProvider.overrideWith((ref) async => offers),
      proPurchaseProvider.overrideWithValue((offer) async => purchased?.add(offer)),
      if (api != null) onboardingApiProvider.overrideWithValue(api),
    ],
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

Future<void> tapStartTrial(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'Start 7-day free trial');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
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

  testWidgets('starting the trial regenerates an AI plan, then shows the plan (FR-004, US1 scenario 5)', (tester) async {
    final api = FakeOnboardingApi();
    final purchased = <ProOffer>[];
    await pump(tester, storePrices, api: api, purchased: purchased);
    await tapStartTrial(tester);
    await tester.pumpAndSettle();
    expect(purchased.single.isAnnual, isTrue, reason: 'annual is selected by default');
    expect(api.forceRegenerateCalls, [true]);
    expect(find.text('PLAN SCREEN'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // let the loading view's staggered fade-in timers finish
  });

  for (final (locale, text) in [
    (const Locale('en'), 'A 3-day full-body plan that fits your 45-minute sessions.'),
    (const Locale('fr'), 'Un programme full-body sur 3 jours adapté à vos séances de 45 minutes.'),
  ]) {
    testWidgets('shows why the plan fits, in the app language (FR-044, ${locale.languageCode})', (tester) async {
      final container = ProviderContainer(overrides: [
        proOffersProvider.overrideWith((ref) async => storePrices),
        onboardingApiProvider.overrideWithValue(FakeOnboardingApi(sources: const ['template'])),
      ]);
      addTearDown(container.dispose);
      final controller = container.read(onboardingControllerProvider.notifier)..giveConsent();
      await controller.submit();
      final router = GoRouter(initialLocation: '/onboarding/trial', routes: [
        GoRoute(path: '/onboarding/trial', builder: (_, __) => const TrialOfferScreen()),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
    });
  }

  group('upgradeToAiPlan waits for the subscription webhook', () {
    Future<(FakeOnboardingApi, OnboardingState)> run(List<String> sources) async {
      final api = FakeOnboardingApi(sources: sources);
      final container = ProviderContainer(overrides: [onboardingApiProvider.overrideWithValue(api)]);
      addTearDown(container.dispose);
      await container.read(onboardingControllerProvider.notifier).upgradeToAiPlan(retryDelay: Duration.zero);
      return (api, container.read(onboardingControllerProvider));
    }

    test('retries while the server still sees a free user, then keeps the AI plan', () async {
      final (api, state) = await run(['template', 'ai']);
      expect(api.forceRegenerateCalls, [true, true]);
      expect(state.upgradeResult!.source, 'ai');
    });

    test('a template_fallback answer is final (the AI was tried)', () async {
      final (api, state) = await run(['template_fallback']);
      expect(api.forceRegenerateCalls.length, 1);
      expect(state.upgradeResult!.fallbackNotice, isTrue);
    });

    test('stops after 3 attempts and keeps the template plan', () async {
      final (api, state) = await run(['template']);
      expect(api.forceRegenerateCalls.length, 3);
      expect(state.upgradeResult!.source, 'template');
    });
  });

  testWidgets('a failed purchase keeps the template plan: no regeneration, error shown', (tester) async {
    final api = FakeOnboardingApi();
    await tester.pumpWidget(const SizedBox()); // reset between pumps
    final router = GoRouter(initialLocation: '/onboarding/trial', routes: [
      GoRoute(path: '/onboarding/trial', builder: (_, __) => const TrialOfferScreen()),
      GoRoute(path: '/plan', builder: (_, __) => const Scaffold(body: Text('PLAN SCREEN'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        proOffersProvider.overrideWith((ref) async => storePrices),
        proPurchaseProvider.overrideWithValue((offer) async => throw Exception('cancelled')),
        onboardingApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ));
    await tester.pumpAndSettle();
    await tapStartTrial(tester);
    await tester.pumpAndSettle();
    expect(api.forceRegenerateCalls, isEmpty);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('no offers in this storefront: purchase hidden, region message, restore kept', (tester) async {
    await pump(tester, null);
    expect(find.text('Tekto Pro is not yet available in your region.'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsNothing);
    expect(find.text('Skip for now'), findsOneWidget);
  });
}
