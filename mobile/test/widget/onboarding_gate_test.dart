// T032 — written before the onboarding screen updates (Constitution II/III).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/onboarding/domain/onboarding_controller.dart';
import 'package:tekto/features/onboarding/domain/onboarding_gate.dart';
import 'package:tekto/features/onboarding/ui/consent_screen.dart';
import 'package:tekto/features/onboarding/ui/health_disclaimer_screen.dart';
import 'package:tekto/features/onboarding/ui/onboarding_quiz_screen.dart';

class FakeApi implements OnboardingApi {
  Map<String, dynamic>? saved;
  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async => saved = profile;
  @override
  Future<GeneratedPlanInfo> generatePlan() async =>
      const GeneratedPlanInfo(planId: 'p1', source: 'template', fallbackNotice: false, notices: ['free_plan_days_capped']);
  @override
  Future<String> deviceTimezone() async => 'Europe/Paris';
}

Widget app(ProviderContainer container, {String initial = '/onboarding/disclaimer', Locale locale = const Locale('en')}) {
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(path: '/onboarding/disclaimer', builder: (_, __) => const HealthDisclaimerScreen()),
    GoRoute(path: '/onboarding/consent', builder: (_, __) => const ConsentScreen()),
    GoRoute(path: '/onboarding/quiz', builder: (_, __) => const OnboardingQuizScreen()),
  ]);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('onboardingRedirect', () {
    test('consent and quiz require the disclaimer first', () {
      for (final loc in ['/onboarding/consent', '/onboarding/quiz', '/onboarding/generating']) {
        expect(onboardingRedirect(location: loc, disclaimerAccepted: false, consentGiven: false), '/onboarding/disclaimer');
      }
    });
    test('the quiz cannot start until consent is given', () {
      expect(onboardingRedirect(location: '/onboarding/quiz', disclaimerAccepted: true, consentGiven: false), '/onboarding/consent');
      expect(onboardingRedirect(location: '/onboarding/quiz', disclaimerAccepted: true, consentGiven: true), isNull);
    });
    test('other routes are not affected', () {
      expect(onboardingRedirect(location: '/onboarding/disclaimer', disclaimerAccepted: false, consentGiven: false), isNull);
      expect(onboardingRedirect(location: '/home', disclaimerAccepted: false, consentGiven: false), isNull);
    });
    test('re-consent when the accepted version is older', () {
      expect(needsReconsent(kConsentVersion), isFalse);
      expect(needsReconsent('2025-01-v0'), isTrue);
      expect(needsReconsent(null), isFalse);
    });
  });

  group('OnboardingController', () {
    test('submit is refused without consent and saves the full profile with it', () async {
      final api = FakeApi();
      final c = ProviderContainer(overrides: [onboardingApiProvider.overrideWithValue(api)]);
      addTearDown(c.dispose);
      final ctrl = c.read(onboardingControllerProvider.notifier);

      await ctrl.submit();
      expect(c.read(onboardingControllerProvider).error, 'consent_required');
      expect(api.saved, isNull);

      ctrl
        ..acceptDisclaimer()
        ..giveConsent(DateTime.utc(2026, 11, 10, 9))
        ..setLanguage('fr')
        ..setGoal('muscle')
        ..setLevel('intermediate')
        ..setDaysPerWeek(6)
        ..setSessionLength(45)
        ..toggleEquipment('dumbbell')
        ..toggleLimitation('knee')
        ..setLimitationsNote('  old ACL surgery ')
        ..setStrength('squat', (weightKg: 80, reps: 5))
        ..setStrength('bench_press', null);
      await ctrl.submit();

      expect(api.saved, {
        'goal': 'muscle', 'level': 'intermediate', 'days_per_week': 6, 'session_length_min': 45,
        'equipment': ['dumbbell'], 'limitations': ['knee'], 'limitations_note': 'old ACL surgery',
        'language': 'fr', 'timezone': 'Europe/Paris', 'consent_at': '2026-11-10T09:00:00.000Z',
        'consent_version': kConsentVersion,
        'strength_estimates': {'squat': {'weight_kg': 80.0, 'reps': 5}},
      });
      final s = c.read(onboardingControllerProvider);
      expect(s.result?.notices, ['free_plan_days_capped']);
      expect(s.isLoading, isFalse);
    });

    test('skipping the whole strength check stores null', () {
      final c = ProviderContainer(overrides: [onboardingApiProvider.overrideWithValue(FakeApi())]);
      addTearDown(c.dispose);
      expect(c.read(onboardingControllerProvider.notifier).profileRow(timezone: 'UTC')['strength_estimates'], isNull);
    });
  });

  testWidgets('the health disclaimer has no skip path and leads to consent', (tester) async {
    final c = ProviderContainer(overrides: [onboardingApiProvider.overrideWithValue(FakeApi())]);
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c));
    await tester.pumpAndSettle();

    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.textContaining(RegExp('skip', caseSensitive: false)), findsNothing);
    expect(find.byType(BackButton), findsNothing);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(c.read(onboardingControllerProvider).disclaimerAccepted, isTrue);
    expect(find.byType(ConsentScreen), findsOneWidget);
  });

  testWidgets('consent must be accepted explicitly before the quiz', (tester) async {
    final c = ProviderContainer(overrides: [onboardingApiProvider.overrideWithValue(FakeApi())]);
    addTearDown(c.dispose);
    c.read(onboardingControllerProvider.notifier).acceptDisclaimer();
    await tester.pumpWidget(app(c, initial: '/onboarding/consent'));
    await tester.pumpAndSettle();

    expect(c.read(onboardingControllerProvider).consentGiven, isFalse);
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(c.read(onboardingControllerProvider).consentGiven, isTrue);
    expect(find.byType(OnboardingQuizScreen), findsOneWidget);
  });

  testWidgets('the quiz starts with language, pre-selected from the device locale', (tester) async {
    final c = ProviderContainer(overrides: [onboardingApiProvider.overrideWithValue(FakeApi())]);
    addTearDown(c.dispose);
    await tester.pumpWidget(app(c, initial: '/onboarding/quiz', locale: const Locale('fr')));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez votre langue'), findsOneWidget);
    expect(c.read(onboardingControllerProvider).language, 'fr');
  });
}
