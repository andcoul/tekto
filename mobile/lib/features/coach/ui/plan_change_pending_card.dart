import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/coach/domain/coach_provider.dart';
import 'package:tekto/features/workout/domain/workout_providers.dart';
import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/services/local_db/daos/exercise_dao.dart';
import 'package:tekto/shared/utils/weight_units.dart';

/// Inline card shown when the coach has proposed a plan change (T078).
///
/// Describes the four change types (ai-services.md §2 `plan_change`) in the user's language
/// and unit — swap old → new, shortened session, deload week, new weight/reps — with the
/// coach's reason and "Apply change" / "No thanks". Nothing changes until the user applies it.
class PlanChangePendingCard extends ConsumerWidget {
  const PlanChangePendingCard({super.key, required this.message});

  final CoachMessageModel message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final change = message.planChangeProposed!;
    final rejected = ref.watch(coachControllerProvider.select((s) => s.rejectedChangeIds.contains(message.id)));

    if (message.planChangeApplied) {
      return _StatusChip(icon: Icons.check_circle, label: l.coachChangeApplied, color: AppColors.accent);
    }
    if (rejected) {
      return _StatusChip(icon: Icons.cancel, label: l.coachChangeDismissed, color: AppColors.onDarkSecondary);
    }

    final language = Localizations.localeOf(context).languageCode;
    final slugs = {change['old_exercise_slug'], change['new_exercise_slug']}.whereType<String>().toList()..sort();
    final names = ref.watch(_exerciseNamesProvider((slugs: slugs.join(','), language: language))).value ?? const {};
    final unit = ref.watch(userPrefsProvider).value?.unit ?? 'kg';
    final reason = (language == 'fr' ? change['reason_fr'] : change['reason_en']) as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        side: const BorderSide(color: AppColors.accent, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.coachPlanChangePending,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: 4),
            Text(
              describePlanChange(change, l, names: names, unit: unit),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(reason, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onDarkSecondary)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref.read(coachControllerProvider.notifier).confirmChange(message.id),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    child: Text(l.coachApplyChange),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref.read(coachControllerProvider.notifier).rejectChange(message.id),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                    child: Text(l.coachDeclineChange),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One line describing [change]; exercise names come from [names] (slug → localized name),
/// falling back to the slug. Weights are stored in kg and shown in [unit].
String describePlanChange(
  Map<String, dynamic> change,
  AppLocalizations l, {
  required Map<String, String> names,
  required String unit,
}) {
  String name(Object? slug) => slug is String ? names[slug] ?? slug : '';
  int? asInt(Object? v) => (v as num?)?.toInt();

  switch (change['type']) {
    case 'exercise_swap':
      return l.coachChangeSwap(name(change['old_exercise_slug']), name(change['new_exercise_slug']));
    case 'session_shorten':
      return l.coachChangeShorten(asInt(change['target_duration_min']) ?? 0);
    case 'deload':
      return l.coachChangeDeload(asInt(change['week_number']) ?? 0);
    case 'weight_adjustment':
      final exercise = name(change['old_exercise_slug'] ?? change['new_exercise_slug']);
      final kg = (change['new_weight_kg'] as num?)?.toDouble();
      final repsMin = asInt(change['new_reps_min']);
      final repsMax = asInt(change['new_reps_max']) ?? repsMin;
      final unitLabel = unit == 'lb' ? l.unitLb : l.unitKg;
      final weight = kg == null ? null : formatWeight(kgToUnit(kg, unit));
      if (weight != null && repsMin != null) {
        return l.coachChangeWeightReps(exercise, weight, unitLabel, repsMin, repsMax!);
      }
      if (weight != null) return l.coachChangeWeight(exercise, weight, unitLabel);
      if (repsMin != null) return l.coachChangeReps(exercise, repsMin, repsMax!);
      return exercise;
    default:
      return l.coachPlanChangePending;
  }
}

/// Localized names for a comma-separated list of slugs, from the device's exercise library.
final _exerciseNamesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, ({String slugs, String language})>((ref, key) async {
  if (key.slugs.isEmpty) return const {};
  final rows = await ExerciseDao(ref.watch(appDatabaseProvider)).getBySlugs(key.slugs.split(','));
  return {for (final e in rows) e.slug: key.language == 'fr' ? e.nameFr : e.nameEn};
});

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      );
}
