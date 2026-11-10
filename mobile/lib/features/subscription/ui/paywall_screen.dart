import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tekto/core/iap/revenuecat_service.dart';
import 'package:tekto/core/theme/app_theme.dart';

/// Feature-specific paywall screen.
///
/// Always renders "Restore purchases" and "Cancel anytime" (FR-031).
/// "Not now" dismiss link NEVER blocks the user from proceeding.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({
    super.key,
    this.featureTitle,
    this.featureBenefit,
  });

  /// Context-specific headline for the locked feature, e.g. "AI Chat Coach".
  final String? featureTitle;

  /// One-line benefit string, e.g. "Unlimited coaching grounded in your plan."
  final String? featureBenefit;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
          tooltip: 'Not now',
        ),
        title: const Text('Tekto Pro'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- Feature value card ----
              _FeatureCard(
                title: widget.featureTitle ?? 'Unlock everything',
                benefit: widget.featureBenefit ??
                    'Unlimited AI coaching, form feedback, and adaptive plans.',
              ),
              const SizedBox(height: AppSpacing.xl),

              // ---- Pricing ----
              const _PricingRow(
                label: 'Monthly',
                price: '\$12.99 / month',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _PricingRow(
                label: 'Annual',
                price: '\$79.99 / year',
                badge: 'Best value',
                selected: true,
              ),
              const Spacer(),

              // ---- Error ----
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // ---- CTA ----
              ElevatedButton(
                onPressed: _loading ? null : _startTrial,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start 7-day free trial'),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Always visible — FR-031
              const Text(
                'Cancel anytime',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.onDarkSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Always visible — FR-031
              TextButton(
                onPressed: _restorePurchases,
                child: const Text('Restore purchases'),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Dismiss
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startTrial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(revenueCatServiceProvider);
      final offerings = await service.getOfferings();
      final annual = offerings?.current?.annual;
      if (annual == null) {
        setState(() => _error = 'No offering available. Try again later.');
        return;
      }
      await service.purchasePackage(annual);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Purchase failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(revenueCatServiceProvider);
      await service.restorePurchases();
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = 'Restore failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.benefit});
  final String title;
  final String benefit;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.accent,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(benefit, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
}

class _PricingRow extends StatelessWidget {
  const _PricingRow({
    required this.label,
    required this.price,
    this.badge,
    this.selected = false,
  });
  final String label;
  final String price;
  final String? badge;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.charcoalElevated,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
        child: Row(
          children: [
            Text(label),
            const Spacer(),
            Text(price),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      );
}
