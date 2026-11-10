import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/onboarding_controller.dart';

/// Unskippable health disclaimer, shown before consent and the first plan (Constitution III).
/// One action only; no skip, close or back control.
class HealthDisclaimerScreen extends ConsumerWidget {
  const HealthDisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),
                const Icon(Icons.health_and_safety_outlined, size: 56, color: AppColors.accent),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.healthDisclaimerTitle, style: Theme.of(context).textTheme.displayMedium, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.base),
                Expanded(
                  child: SingleChildScrollView(child: Text(l10n.healthDisclaimerBody, textAlign: TextAlign.center)),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () {
                    ref.read(onboardingControllerProvider.notifier).acceptDisclaimer();
                    context.go('/onboarding/consent');
                  },
                  child: Text(l10n.healthDisclaimerAcknowledge),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
