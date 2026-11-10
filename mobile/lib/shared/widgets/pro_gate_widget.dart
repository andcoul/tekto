import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/features/workout/domain/workout_controller.dart';

/// Wraps a child widget with a Pro entitlement check.
///
/// - If the user **is Pro**: child is shown normally and taps pass through.
/// - If the user **is not Pro** and a workout is active: tap shows paywall as a
///   bottom sheet so the workout screen remains visible (Principle III).
/// - If the user **is not Pro** with no active workout: tap triggers the
///   provided [onShowPaywall] callback (typically full-screen paywall push).
class ProGateWidget extends ConsumerWidget {
  const ProGateWidget({
    super.key,
    required this.child,
    required this.onShowPaywall,
    this.featureLabel = 'This feature',
  });

  final Widget child;

  /// Called when paywall should be shown (no active workout).
  final VoidCallback onShowPaywall;

  /// Human-readable label for the locked feature (used in bottom-sheet copy).
  final String featureLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementProvider);
    final isPro = entitlement.value?.isPro ?? false;

    if (isPro) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleTap(context, ref),
      child: IgnorePointer(child: child),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    final isWorkoutActive = ref.read(workoutControllerProvider).isActive;

    if (isWorkoutActive) {
      // Workout in progress — show bottom sheet so the workout is not obscured.
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => _PaywallBottomSheet(featureLabel: featureLabel),
      );
    } else {
      onShowPaywall();
    }
  }
}

class _PaywallBottomSheet extends StatelessWidget {
  const _PaywallBottomSheet({required this.featureLabel});
  final String featureLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Upgrade to Pro',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '$featureLabel is a Tekto Pro feature.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigation to paywall deferred to after workout completion.
              },
              child: const Text('See Pro features'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue workout'),
            ),
          ],
        ),
      ),
    );
  }
}
