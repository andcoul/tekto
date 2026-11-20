import 'dart:async';

import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/data/user_profile_provider.dart';
import '../domain/onboarding_controller.dart';

class PlanGenerationScreen extends ConsumerStatefulWidget {
  const PlanGenerationScreen({super.key, this.upgrade = false});

  /// True right after a trial started during onboarding: regenerate as an AI plan, then
  /// show the plan instead of the trial offer (FR-004).
  final bool upgrade;

  @override
  ConsumerState<PlanGenerationScreen> createState() => _PlanGenerationScreenState();
}

class _PlanGenerationScreenState extends ConsumerState<PlanGenerationScreen> {
  static const _timeout = Duration(seconds: 35);
  bool _timedOut = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    if (widget.upgrade) {
      Future.microtask(() => ref.read(onboardingControllerProvider.notifier).upgradeToAiPlan());
    }
    _timeoutTimer = Timer(_timeout, () {
      if (mounted && ref.read(onboardingControllerProvider).isLoading) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _retry() {
    final controller = ref.read(onboardingControllerProvider.notifier);
    widget.upgrade ? controller.upgradeToAiPlan() : controller.submit();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);

    // The server always returns a plan (FR-003b); errors here are network/auth failures.
    ref.listen(onboardingControllerProvider, (previous, next) {
      if (widget.upgrade) {
        if (next.upgradeResult != null && previous?.upgradeResult == null) context.go('/plan');
        return;
      }
      if (next.result != null && previous?.result == null) {
        ref.invalidate(userProfileProvider); // the profile now exists → router leaves onboarding
        context.go('/onboarding/trial');
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: _timedOut
                ? _TimeoutView(
                    onRetry: () {
                      setState(() => _timedOut = false);
                      _retry();
                    },
                  )
                : state.error != null
                    ? _ErrorView(
                        error: state.error!,
                        onRetry: _retry,
                      )
                    : _LoadingView(),
          ),
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: AppColors.glacier,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Building your plan…',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Analysing your profile and selecting the best exercises for you.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ].animate(interval: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
      );
}

class _TimeoutView extends StatelessWidget {
  const _TimeoutView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: AppColors.mist),
          const SizedBox(height: AppSpacing.lg),
          Text(AppLocalizations.of(context).planGenSlow,
              style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(AppLocalizations.of(context).planGenCheckConnection,
              style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).commonTryAgain)),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: AppSpacing.lg),
          Text(AppLocalizations.of(context).planGenAiDown,
              style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(AppLocalizations.of(context).planGenTryLater,
              style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).commonTryAgain)),
        ],
      );
}
