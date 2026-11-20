import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/bundled_clip.dart';
import '../domain/pro_offers.dart';

/// The Pro feature that opened the paywall; picks the value clip and copy (FR-031).
enum PaywallFeature {
  formCheck('form_check'),
  coach('coach'),
  adaptivePlan('adaptive_plan'),
  general('general');

  const PaywallFeature(this.key);

  /// Used in `/paywall?feature=<key>` and the clip file names.
  final String key;

  String get clipAsset => 'assets/video/paywall_$key.mp4';
  String captionsAsset(String language) => 'assets/video/paywall_${key}_$language.vtt';

  static PaywallFeature fromKey(String? key) =>
      values.firstWhere((f) => f.key == key, orElse: () => PaywallFeature.general);
}

/// Full-screen paywall (`/paywall?feature=…`). Never shown over a workout in progress: during
/// a workout [ProGateWidget] shows [PaywallView] in a bottom sheet instead (FR-030).
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, this.feature = PaywallFeature.general});
  final PaywallFeature feature;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: const CloseButton()),
        body: SafeArea(child: PaywallView(feature: feature)),
      );
}

/// Paywall content shared by the full screen and the in-workout bottom sheet (T055):
/// a short value clip for [feature], store-localized prices (annual selected by default,
/// savings computed from the store prices), and — always visible — cancel-anytime text and
/// Restore purchases (FR-031, FR-032). Offline, purchase and restore are disabled with a notice.
class PaywallView extends ConsumerStatefulWidget {
  const PaywallView({super.key, required this.feature, this.inSheet = false});
  final PaywallFeature feature;

  /// In the workout bottom sheet: compact clip and a "Continue workout" action.
  final bool inSheet;

  @override
  ConsumerState<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends ConsumerState<PaywallView> {
  bool _annual = true;
  bool _busy = false;
  String? _message;

  Future<void> _purchase(ProOffer offer) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(proPurchaseProvider)(offer);
      if (mounted) Navigator.of(context).maybePop();
    } on Object {
      if (mounted) setState(() => _message = l.paywallPurchaseFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(proRestoreProvider)();
    } on Object {
      if (mounted) setState(() => _message = l.paywallRestoreFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final offers = ref.watch(proOffersProvider);
    // Unknown connectivity counts as offline: never start a purchase that cannot complete.
    final online = ref.watch(isOnlineProvider).value ?? false;
    final enabled = online && !_busy;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
          mainAxisSize: widget.inSheet ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  child:
                      SizedBox(height: widget.inSheet ? 120 : 200, child: PaywallValueVideo(feature: widget.feature)),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(l.paywallTitle, style: text.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xs),
                Text(_featureLine(l, widget.feature), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.base),
                if (!online)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(l.paywallOffline,
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.glacier)),
                  ),
                ...offers.when(
                  loading: () => [const Center(child: CircularProgressIndicator())],
                  error: (_, __) => [Text(l.proUnavailableInRegion, textAlign: TextAlign.center)],
                  data: (list) {
                    if (list == null || list.isEmpty)
                      return [Text(l.proUnavailableInRegion, textAlign: TextAlign.center)];
                    final selected = list.firstWhere((o) => o.isAnnual == _annual, orElse: () => list.first);
                    final savings = annualSavingsPercent(list);
                    return [
                      for (final o in list)
                        RadioListTile<bool>(
                          value: o.isAnnual,
                          groupValue: selected.isAnnual,
                          onChanged: enabled ? (v) => setState(() => _annual = v ?? true) : null,
                          title: Text(o.isAnnual ? l.paywallAnnual : l.paywallMonthly),
                          subtitle: o.isAnnual && savings != null ? Text(l.paywallSave(savings)) : null,
                          secondary: Text(o.priceString, style: text.titleMedium),
                        ),
                      if (_message != null)
                        Text(_message!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                          onPressed: enabled ? () => _purchase(selected) : null, child: Text(l.paywallTrialCta)),
                    ];
                  },
                ),
              ])),
            ),
            // Pinned outside the scroll area so they are always visible (FR-031).
            const SizedBox(height: AppSpacing.sm),
            Text(l.paywallCancelAnytime, textAlign: TextAlign.center, style: text.bodySmall),
            TextButton(onPressed: enabled ? _restore : null, child: Text(l.paywallRestore)),
            if (widget.inSheet)
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.paywallContinueWorkout))
            else
              TextButton(
                  onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                  child: Text(l.paywallNotNow)),
          ]),
    );
  }

  static String _featureLine(AppLocalizations l, PaywallFeature f) => switch (f) {
        PaywallFeature.formCheck => l.paywallFeatureFormCheck,
        PaywallFeature.coach => l.paywallFeatureCoach,
        PaywallFeature.adaptivePlan => l.paywallFeatureAdaptivePlan,
        PaywallFeature.general => l.paywallFeatureGeneral,
      };
}

/// The bundled value clip for a feature (≤ 15 s, muted, looping, captioned).
class PaywallValueVideo extends StatelessWidget {
  const PaywallValueVideo({super.key, required this.feature});
  final PaywallFeature feature;

  @override
  Widget build(BuildContext context) => BundledClip(
        asset: feature.clipAsset,
        captionsAsset: feature.captionsAsset,
        placeholder: const ColoredBox(
          color: AppColors.deep,
          child: Center(child: Icon(Icons.auto_awesome, size: 48, color: AppColors.glacier)),
        ),
      );
}
