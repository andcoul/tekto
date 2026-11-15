import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/subscription/domain/entitlement_provider.dart';
import '../../features/subscription/ui/paywall_screen.dart';
import '../../features/workout/domain/workout_controller.dart';

/// Gates a Pro feature (FR-029, FR-030, T056).
///
/// - Pro: [child] works normally.
/// - Free during a workout: the paywall opens as a bottom sheet; the workout stays visible
///   and "Continue workout" closes it. A workout in progress is never interrupted.
/// - Free otherwise: the full paywall for [feature] opens (default: `/paywall?feature=…`).
class ProGateWidget extends ConsumerWidget {
  const ProGateWidget({super.key, required this.child, required this.feature, this.onShowPaywall});

  final Widget child;
  final PaywallFeature feature;

  /// Opens the full-screen paywall; defaults to pushing `/paywall?feature=<key>`.
  final void Function(PaywallFeature feature)? onShowPaywall;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;
    if (isPro) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showProPaywall(context, ref, feature, onShowPaywall: onShowPaywall),
      child: IgnorePointer(child: child),
    );
  }
}

/// Shows the right paywall for [feature]: a bottom sheet during a workout, otherwise the full
/// paywall. Also used where the gate is a server answer (e.g. the coach's QUOTA_EXCEEDED).
Future<void> showProPaywall(BuildContext context, WidgetRef ref, PaywallFeature feature,
    {void Function(PaywallFeature feature)? onShowPaywall}) async {
  if (ref.read(workoutControllerProvider).isWorkoutActive) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(child: PaywallView(feature: feature, inSheet: true)),
    );
    return;
  }
  if (onShowPaywall != null) {
    onShowPaywall(feature);
  } else {
    await context.push('/paywall?feature=${feature.key}');
  }
}
