import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/subscription/ui/paywall_screen.dart';
import 'package:tekto/core/iap/revenuecat_service.dart';

// ---------------------------------------------------------------------------
// T064 — Widget test: PaywallScreen
// ---------------------------------------------------------------------------
// Verifies that "Restore purchases" and "Cancel anytime" are ALWAYS rendered
// regardless of entitlement state (FR-031).

void main() {
  group('PaywallScreen', () {
    Widget buildSubject() => ProviderScope(
          overrides: [
            // RevenueCatService is not exercised in this render test;
            // override with a no-op to avoid DI errors.
            revenueCatServiceProvider.overrideWithValue(
              _NoopRevenueCatService(),
            ),
          ],
          child: const MaterialApp(home: PaywallScreen()),
        );

    testWidgets(
      'always shows "Restore purchases" text',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Restore purchases'), findsOneWidget);
      },
    );

    testWidgets(
      'always shows "Cancel anytime" text',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Cancel anytime'), findsOneWidget);
      },
    );

    testWidgets(
      'renders "Not now" dismiss button',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Not now'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'renders trial CTA button',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('Start 7-day free trial'), findsOneWidget);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// No-op stub — RevenueCatService
// ---------------------------------------------------------------------------

class _NoopRevenueCatService implements RevenueCatService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
