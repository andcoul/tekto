import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/plan/domain/adaptation_provider.dart';
import 'package:tekto/features/workout/domain/workout_providers.dart';
import 'package:tekto/shared/utils/weight_units.dart';

/// What changed for next week and why (FR-027, T086): sessions completed of scheduled, each
/// exercise's old → new value in the user's unit, and the reason in the user's language.
/// Opened from the adaptation card; never shown on its own.
class AdaptationSummaryScreen extends ConsumerWidget {
  const AdaptationSummaryScreen({super.key, required this.summary});

  final AdaptationSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final unit = ref.watch(userPrefsProvider).value?.unit ?? 'kg';
    final names =
        ref.watch(planExerciseNamesProvider(summary.changes.map((c) => c.planExerciseId).join(','))).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(l.adaptationTitle(summary.week))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.base),
                children: [
                  Text(
                    l.adaptationSessionsCompleted(summary.sessionsCompleted, summary.sessionsScheduled),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (summary.summary(lang).isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(summary.summary(lang), style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: AppSpacing.base),
                  if (summary.changes.isEmpty)
                    Text(l.adaptationNoChanges, style: Theme.of(context).textTheme.bodyLarge)
                  else
                    for (final change in summary.changes)
                      _ChangeCard(
                        change: change,
                        name: switch (names[change.planExerciseId]) {
                          final n? => lang == 'fr' ? n.fr : n.en,
                          null => null,
                        },
                        unit: unit,
                        repsLabel: l.adaptationReps,
                        lang: lang,
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.canPop() ? context.pop() : context.go('/plan'),
                  child: Text(l.adaptationGotIt),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({
    required this.change,
    required this.name,
    required this.unit,
    required this.repsLabel,
    required this.lang,
  });

  final AdaptationChange change;
  final String? name;
  final String unit;
  final String repsLabel;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final up = change.newValue > change.oldValue;
    final String values;
    if (change.isWeight) {
      final from = formatWeight(kgToUnit(change.oldValue, unit));
      final to = formatWeight(kgToUnit(change.newValue, unit));
      values = '$from → $to $unit';
    } else {
      values = '${change.oldValue.round()} → ${change.newValue.round()} $repsLabel';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name != null) Text(name!, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 18, color: AppColors.glacier),
                const SizedBox(width: 4),
                Text(values, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(change.reason(lang), style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
