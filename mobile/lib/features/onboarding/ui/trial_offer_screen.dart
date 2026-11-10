import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../subscription/domain/pro_offers.dart';

/// Skippable post-plan trial offer (FR-004, T043). Never blocks the plan: "Skip for now" is
/// always visible. Prices come from the store (FR-032); Restore and cancel-anytime are always
/// shown (FR-031).
class TrialOfferScreen extends ConsumerStatefulWidget {
  const TrialOfferScreen({super.key});

  @override
  ConsumerState<TrialOfferScreen> createState() => _TrialOfferScreenState();
}

class _TrialOfferScreenState extends ConsumerState<TrialOfferScreen> {
  bool _annual = true;
  bool _busy = false;
  String? _error;

  Future<void> _purchase(ProOffer offer) async {
    if (offer.package == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(revenueCatServiceProvider).purchasePackage(offer.package!);
      if (mounted) context.go('/plan');
    } on Exception {
      if (mounted)
        setState(
            () => _error = AppLocalizations.of(context).paywallPurchaseFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      await ref.read(revenueCatServiceProvider).restorePurchases();
    } on Exception {
      // Nothing to restore, or the store is unreachable; the user can continue on free.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offers = ref.watch(proOffersProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scrollable so it never overflows on small screens or large Dynamic Type sizes.
              Expanded(
                  child: ListView(children: [
                const SizedBox(height: AppSpacing.xl),
                const Icon(Icons.auto_awesome,
                    size: 56, color: AppColors.accent),
                const SizedBox(height: AppSpacing.base),
                Text(l10n.trialTitle,
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.trialSubtitle, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                ...offers.when(
                  loading: () =>
                      [const Center(child: CircularProgressIndicator())],
                  error: (_, __) => [
                    Text(l10n.proUnavailableInRegion,
                        textAlign: TextAlign.center)
                  ],
                  data: (list) {
                    if (list == null)
                      return [
                        Text(l10n.proUnavailableInRegion,
                            textAlign: TextAlign.center)
                      ];
                    final selected = list.firstWhere(
                        (o) => o.isAnnual == _annual,
                        orElse: () => list.first);
                    return [
                      for (final o in list)
                        RadioListTile<bool>(
                          value: o.isAnnual,
                          groupValue: selected.isAnnual,
                          onChanged: (v) => setState(() => _annual = v ?? true),
                          title: Text(o.isAnnual
                              ? l10n.paywallAnnual
                              : l10n.paywallMonthly),
                          secondary: Text(o.priceString,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                      const SizedBox(height: AppSpacing.base),
                      if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center),
                      ElevatedButton(
                        onPressed: _busy ? null : () => _purchase(selected),
                        child: Text(l10n.trialStart),
                      ),
                    ];
                  },
                ),
              ])),
              // Pinned outside the scroll area so they are always visible (FR-004, FR-031).
              Text(l10n.paywallCancelAnytime,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              TextButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(l10n.paywallRestore)),
              TextButton(
                  onPressed: () => context.go('/plan'),
                  child: Text(l10n.trialSkip)),
            ],
          ),
        ),
      ),
    );
  }
}
