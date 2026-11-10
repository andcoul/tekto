import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/coach/domain/coach_provider.dart';
import 'package:tekto/shared/models/coach_model.dart';

/// Inline card shown when the coach has proposed a plan change.
///
/// Shows old → new exercise (or other change type) with "Apply change" and
/// "No thanks" buttons.
class PlanChangePendingCard extends ConsumerWidget {
  const PlanChangePendingCard({super.key, required this.message});

  final CoachMessageModel message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final change = message.planChangeProposed!;
    final applied = message.planChangeApplied ?? false;
    final rejected = message.planChangeRejected ?? false;

    if (applied) {
      return _StatusChip(
        icon: Icons.check_circle,
        label: 'Change applied',
        color: AppColors.accent,
      );
    }

    if (rejected) {
      return _StatusChip(
        icon: Icons.cancel,
        label: 'Change dismissed',
        color: AppColors.onDarkSecondary,
      );
    }

    final newSlug = change['new_exercise_slug'] as String? ?? '';
    final reasonEn = change['reason_en'] as String? ?? '';

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
              'Plan change proposed',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.accent,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'New exercise: $newSlug',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (reasonEn.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                reasonEn,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onDarkSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ref
                        .read(coachControllerProvider.notifier)
                        .confirmChange(message.id),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('Apply change'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(coachControllerProvider.notifier)
                        .rejectChange(message.id),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text('No thanks'),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      );
}
