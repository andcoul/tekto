import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/subscription/domain/entitlement_provider.dart';

/// Skippable post-plan trial offer.
/// Constitution Principle VI + FR-030: MUST NOT block access to the plan.
/// "Skip for now" link proceeds to plan on free tier.
class TrialOfferScreen extends ConsumerStatefulWidget {
  const TrialOfferScreen({super.key});

  @override
  ConsumerState<TrialOfferScreen> createState() => _TrialOfferScreenState();
}

class _TrialOfferScreenState extends ConsumerState<TrialOfferScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _startTrial() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(entitlementProvider.notifier).startFreeTrial();
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Purchase failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.auto_awesome, size: 56, color: AppColors.accent),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Start your free trial',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Unlimited AI coaching, form check, and adaptive plans.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              _FeatureBullet(
                icon: Icons.chat_bubble_outline,
                text: 'Unlimited AI coaching',
              ),
              _FeatureBullet(
                icon: Icons.videocam_outlined,
                text: 'Camera form check with rep counting',
              ),
              _FeatureBullet(
                icon: Icons.trending_up,
                text: 'Weekly adaptive plan updates',
              ),
              _FeatureBullet(
                icon: Icons.download_outlined,
                text: 'Download videos for offline use',
              ),
              const Spacer(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center),
                ),
              ElevatedButton(
                onPressed: _loading ? null : _startTrial,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onDark,
                        ),
                      )
                    : const Text('Start 7-day free trial'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cancel anytime. No charge until trial ends.',
                style: TextStyle(color: AppColors.onDarkSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Not now — start for free'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
}
