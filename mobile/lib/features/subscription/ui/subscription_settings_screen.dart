import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/settings/domain/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Subscription management screen.
///
/// Shows current tier, trial / period end dates, and deep-links to the native
/// subscription management page on App Store / Play Store.
class SubscriptionSettingsScreen extends ConsumerWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = ref.watch(entitlementProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).settingsSubscription)),
      body: entitlement.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppLocalizations.of(context).commonLoadError)),
        data: (state) => _Body(state: state),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});
  final EntitlementState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.base),
      children: [
        // ---- Current tier ----
        _SectionHeader('Current plan'),
        ListTile(
          leading: Icon(
            state.isPro ? Icons.star : Icons.star_border,
            color: state.isPro ? AppColors.accent : null,
          ),
          title: Text(state.isPro ? 'Tekto Pro' : 'Free'),
          subtitle: _buildSubtitle(context, state),
        ),
        const Divider(),

        // ---- Manage subscription ----
        _SectionHeader('Manage'),
        ListTile(
          leading: const Icon(Icons.open_in_new),
          title: Text(AppLocalizations.of(context).settingsManageSubscription),
          subtitle: Text(AppLocalizations.of(context).subscriptionManageHint),
          onTap: () => _openManageSubscription(Theme.of(context).platform),
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: Text(AppLocalizations.of(context).subscriptionRestore),
          onTap: () => _restorePurchases(context, ref),
        ),
        const Divider(),

        // ---- Legal ----
        _SectionHeader('Legal'),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsPrivacyPolicy),
          onTap: () => _launchUrl(kPrivacyPolicyUrl),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).subscriptionTerms),
          onTap: () => _launchUrl('https://tekto.app/terms'),
        ),
      ],
    );
  }

  Text? _buildSubtitle(BuildContext context, EntitlementState state) {
    if (!state.isPro) return null;
    final l = AppLocalizations.of(context);
    if (state.isTrial && state.periodEndsAt != null) {
      return Text(l.subscriptionTrialEnds(_formatDate(state.periodEndsAt!)));
    }
    if (state.periodEndsAt != null) {
      return Text(l.subscriptionRenews(_formatDate(state.periodEndsAt!)));
    }
    return null;
  }

  Future<void> _openManageSubscription(TargetPlatform platform) async {
    // Platform-specific subscription management URL
    const iosUrl = 'https://apps.apple.com/account/subscriptions';
    const androidUrl =
        'https://play.google.com/store/account/subscriptions';
    final uri = Uri.parse(
      platform == TargetPlatform.iOS
          ? iosUrl
          : androidUrl,
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final service = ref.read(revenueCatServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.restorePurchases();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).subscriptionRestored)),
      );
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).subscriptionRestoreFailed)),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
            left: 16, top: AppSpacing.base, bottom: AppSpacing.sm),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.onDarkSecondary,
              ),
        ),
      );
}
