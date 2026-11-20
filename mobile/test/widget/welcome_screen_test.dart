// T124 — written before welcome_screen.dart (FR-043). The welcome screen is the only
// onboarding screen before sign-in (spec US1 order: welcome → auth → disclaimer → …).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/onboarding/domain/onboarding_gate.dart';
import 'package:tekto/features/onboarding/ui/welcome_screen.dart';

Future<void> pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
  final router = GoRouter(initialLocation: '/onboarding/welcome', routes: [
    GoRoute(path: '/onboarding/welcome', builder: (_, __) => const WelcomeScreen()),
    GoRoute(path: '/auth', builder: (_, __) => const Scaffold(body: Text('AUTH SCREEN'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('signedOutRedirect', () {
    test('a signed-out launch lands on the welcome screen, not /auth', () {
      expect(signedOutRedirect('/home'), '/onboarding/welcome');
      expect(signedOutRedirect('/onboarding/disclaimer'), '/onboarding/welcome');
    });
    test('welcome and auth are reachable signed out', () {
      expect(signedOutRedirect('/onboarding/welcome'), isNull);
      expect(signedOutRedirect('/auth'), isNull);
    });
  });

  testWidgets('shows the bundled welcome video and the value promise', (tester) async {
    await pump(tester);
    expect(find.byType(WelcomeVideo), findsOneWidget);
    expect(find.text('Build your strength'), findsOneWidget);
    expect(find.textContaining('real video for every move'), findsOneWidget);
  });

  testWidgets('the value promise is localized', (tester) async {
    await pump(tester, locale: const Locale('fr'));
    expect(find.text('Construisez votre force'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
  });

  for (final label in ['Get started', 'Skip']) {
    testWidgets('"$label" leads to sign-in', (tester) async {
      await pump(tester);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('AUTH SCREEN'), findsOneWidget);
    });
  }
}
