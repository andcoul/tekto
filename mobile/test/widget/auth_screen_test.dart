// T101 — FR-005 sign-in options.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/auth/ui/auth_screen.dart';

void main() {
  testWidgets('offers Apple, Google and email sign-in, and no guest mode', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AuthScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Apple'), findsOneWidget);
    expect(find.textContaining('Google'), findsOneWidget);
    expect(find.textContaining(RegExp('email', caseSensitive: false)), findsWidgets);
    expect(find.textContaining(RegExp('guest|invité', caseSensitive: false)), findsNothing);
  });

  testWidgets('email path offers both sign in and account creation', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AuthScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with email'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2), reason: 'email + password');
    expect(find.textContaining(RegExp('create an account', caseSensitive: false)), findsOneWidget);
  });
}
