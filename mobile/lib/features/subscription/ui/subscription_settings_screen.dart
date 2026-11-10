import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/iap/revenuecat_service.dart';
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
      appBar: AppBar(title: const Text('Subscription')),
      body: entitlement.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
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
          subtitle: _buildSubtitle(state),
        ),
        const Divider(),

        // ---- Manage subscription ----
        _SectionHeader('Manage'),
        ListTile(
          leading: const Icon(Icons.open_in_new),
          title: const Text('Manage subscription'),
          subtitle: const Text('Opens App Store or Google Play'),
          onTap: _openManageSubscription,
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore purchases'),
          onTap: () => _restorePurchases(context, ref),
        ),
        const Divider(),

        // ---- Legal ----
        _SectionHeader('Legal'),
        ListTile(
          title: const Text('Privacy Policy'),
          onTap: () => _launchUrl('https://tekto.app/privacy'),
        ),
        ListTile(
          title: const Text('Terms of Service'),
          onTap: () => _launchUrl('https://tekto.app/terms'),
        ),
      ],
    );
  }

  Text? _buildSubtitle(EntitlementState state) {
    if (!state.isPro) return null;
    if (state.isTrial && state.periodEndsAt != null) {
      return Text(
          'Trial ends ${_formatDate(state.periodEndsAt!)}');
    }
    if (state.periodEndsAt != null) {
      return Text('Renews ${_formatDate(state.periodEndsAt!)}');
    }
    return null;
  }

  Future<void> _openManageSubscription() async {
    // Platform-specific subscription management URL
    const iosUrl = 'https://apps.apple.com/account/subscriptions';
    const androidUrl =
        'https://play.google.com/store/account/subscriptions';
    final uri = Uri.parse(
      Theme.of(_scaffoldContext!).platform == TargetPlatform.iOS
          ? iosUrl
          : androidUrl,
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ignore: use_build_context_synchronously
  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    final service = ref.read(revenueCatServiceProvider);
    try {
      await service.restorePurchases();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchases restored.')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore failed. Try again.')),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // Workaround: store context ref for platform check
  BuildContext? _scaffoldContext;
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
