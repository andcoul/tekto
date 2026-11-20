import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/plan/domain/adaptation_provider.dart';

/// Explains the newest weekly adaptation in one line (FR-027, US5 scenario 4, T086): a
/// dismissible card on the plan and home screens, never a modal (Constitution VI). "Why?"
/// opens the full summary. Opening or dismissing it marks the week as seen on this device.
class AdaptationCard extends ConsumerWidget {
  const AdaptationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unseen = ref.watch(unseenAdaptationProvider).value;
    if (unseen == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final (:planId, :summary) = unseen;
    void markSeen() => ref.read(adaptationServiceProvider).markSeen(planId, summary.week);

    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.base),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, 0, AppSpacing.sm),
        child: Row(
          children: [
            const Icon(Icons.trending_up, color: AppColors.glacier),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.adaptationTitle(summary.week), style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(summary.summary(lang), style: Theme.of(context).textTheme.bodyMedium),
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 48)),
                    onPressed: () {
                      markSeen();
                      context.push('/plan/adaptation', extra: summary);
                    },
                    child: Text(l.adaptationWhy),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l.adaptationDismiss,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: markSeen,
            ),
          ],
        ),
      ),
    );
  }
}
