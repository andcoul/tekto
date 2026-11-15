// T053 — written before the ProGateWidget update (FR-030, Constitution V): during a workout the
// paywall is a bottom sheet over a still-visible workout; otherwise the full paywall opens.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/features/subscription/domain/pro_offers.dart';
import 'package:tekto/features/subscription/ui/paywall_screen.dart';
import 'package:tekto/features/workout/domain/workout_controller.dart';
import 'package:tekto/shared/widgets/pro_gate_widget.dart';

class _Workout extends WorkoutController {
  _Workout(this.active);
  final bool active;
  @override
  WorkoutState build() => WorkoutState(isWorkoutActive: active);
}

Future<List<PaywallFeature>> pump(WidgetTester tester, {required bool pro, required bool workoutActive}) async {
  final fullScreen = <PaywallFeature>[];
  var tapped = 0;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      entitlementProvider.overrideWith(
          (ref) => Stream.value(pro ? const EntitlementState(isPro: true, isTrial: false) : EntitlementState.free)),
      workoutControllerProvider.overrideWith(() => _Workout(workoutActive)),
      proOffersProvider.overrideWith((ref) async => const [ProOffer(isAnnual: true, priceString: '79,99 €', price: 79.99)]),
      isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      proPurchaseProvider.overrideWithValue((_) async {}),
      proRestoreProvider.overrideWithValue(() async {}),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(children: [
          const Text('WORKOUT SCREEN'),
          ProGateWidget(
            feature: PaywallFeature.formCheck,
            onShowPaywall: fullScreen.add,
            child: TextButton(onPressed: () => tapped++, child: const Text('Form check')),
          ),
          Text('tapped $tapped'),
        ]),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return fullScreen;
}

void main() {
  testWidgets('Pro: the child works normally', (tester) async {
    final fullScreen = await pump(tester, pro: true, workoutActive: true);
    await tester.tap(find.text('Form check'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallView), findsNothing);
    expect(fullScreen, isEmpty);
  });

  testWidgets('free during a workout: bottom-sheet paywall, workout still visible, no full-screen paywall', (tester) async {
    final fullScreen = await pump(tester, pro: false, workoutActive: true);
    await tester.tap(find.text('Form check'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.byType(PaywallView)), findsOneWidget);
    expect(find.text('WORKOUT SCREEN'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(fullScreen, isEmpty);

    await tester.tap(find.text('Continue workout'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('free with no workout: the full paywall opens for the feature', (tester) async {
    final fullScreen = await pump(tester, pro: false, workoutActive: false);
    await tester.tap(find.text('Form check'));
    await tester.pumpAndSettle();
    expect(fullScreen, [PaywallFeature.formCheck]);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
