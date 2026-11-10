import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/onboarding_controller.dart';
import '../domain/onboarding_gate.dart';

/// Explicit consent to health-data processing (GDPR Art. 9; Constitution II; T038).
///
/// During onboarding the consent is kept in the controller and saved with the profile.
/// With [reconsent] (an existing user who accepted an older text) it is saved immediately.
class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key, this.reconsent = false});
  final bool reconsent;

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
                const Icon(Icons.lock_outline, size: 56, color: AppColors.accent),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.consentTitle, style: Theme.of(context).textTheme.displayMedium, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.base),
                Expanded(child: SingleChildScrollView(child: Text(l10n.consentBody))),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: () async {
                    final now = DateTime.now().toUtc();
                    ref.read(onboardingControllerProvider.notifier).giveConsent(now);
                    if (reconsent) {
                      final client = Supabase.instance.client;
                      await client.from('users').update({
                        'consent_at': now.toIso8601String(),
                        'consent_version': kConsentVersion,
                      }).eq('id', client.auth.currentUser!.id);
                      if (context.mounted) context.go('/home');
                      return;
                    }
                    if (context.mounted) context.go('/onboarding/quiz');
                  },
                  child: Text(l10n.consentAgree),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
