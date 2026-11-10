import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/features/workout/domain/workout_controller.dart';
import 'package:tekto/shared/widgets/pro_gate_widget.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeWorkoutController extends StateNotifier<WorkoutState>
    implements WorkoutController {
  _FakeWorkoutController(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Tests — T063
// ---------------------------------------------------------------------------
// Verifies that ProGateWidget shows a bottom-sheet paywall (not a full-screen
// modal) when the user is not Pro AND an active workout is in progress.

void main() {
  group('ProGateWidget', () {
    testWidgets(
      'shows bottom-sheet paywall (not full-screen) when workout is active',
      (tester) async {
        var paywallShownFullScreen = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // User is NOT Pro
              entitlementProvider.overrideWith(
                (ref) => Stream.value(
                  const EntitlementState(isPro: false, isTrial: false),
                ),
              ),
              // A workout IS active
              workoutControllerProvider.overrideWith(
                () => _FakeWorkoutController(
                  const WorkoutState(status: WorkoutStatus.active),
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProGateWidget(
                  onShowPaywall: () => paywallShownFullScreen = true,
                  child: const Text('Pro content'),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap the gated widget
        await tester.tap(find.text('Pro content'));
        await tester.pumpAndSettle();

        // Paywall shown as bottom sheet
        expect(find.text('Upgrade to Pro'), findsOneWidget);
        // Full-screen paywall callback must NOT have fired
        expect(paywallShownFullScreen, isFalse);
      },
    );

    testWidgets(
      'calls onShowPaywall when no workout is active',
      (tester) async {
        var paywallShownFullScreen = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entitlementProvider.overrideWith(
                (ref) => Stream.value(
                  const EntitlementState(isPro: false, isTrial: false),
                ),
              ),
              workoutControllerProvider.overrideWith(
                () => _FakeWorkoutController(
                  const WorkoutState(status: WorkoutStatus.idle),
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProGateWidget(
                  onShowPaywall: () => paywallShownFullScreen = true,
                  child: const Text('Pro content'),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Pro content'));
        await tester.pumpAndSettle();

        expect(paywallShownFullScreen, isTrue);
      },
    );

    testWidgets(
      'renders child normally when user is Pro (no interception)',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entitlementProvider.overrideWith(
                (ref) => Stream.value(
                  const EntitlementState(isPro: true, isTrial: false),
                ),
              ),
              workoutControllerProvider.overrideWith(
                () => _FakeWorkoutController(
                  const WorkoutState(status: WorkoutStatus.idle),
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProGateWidget(
                  onShowPaywall: () {},
                  child: GestureDetector(
                    onTap: () => tapped = true,
                    child: const Text('Pro content'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Pro content'));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      },
    );
  });
}
