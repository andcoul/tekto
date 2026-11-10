import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/library/data/exercise_repository.dart';
import 'package:tekto/shared/models/exercise_model.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';

/// Bottom sheet for swapping an exercise in the plan.
///
/// Lists alternatives filtered by the same `muscle_primary` and user's
/// available equipment. Each alternative shows name + video thumbnail.
/// Selecting one calls the `swap-exercise` Edge Function.
class ExerciseSwapSheet extends ConsumerStatefulWidget {
  const ExerciseSwapSheet({
    super.key,
    required this.planExerciseId,
    required this.currentExerciseSlug,
    required this.musclePrimary,
    required this.userEquipment,
  });

  final String planExerciseId;
  final String currentExerciseSlug;
  final String musclePrimary;
  final List<String> userEquipment;

  @override
  ConsumerState<ExerciseSwapSheet> createState() => _ExerciseSwapSheetState();
}

class _ExerciseSwapSheetState extends ConsumerState<ExerciseSwapSheet> {
  bool _swapping = false;

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(
      filteredExercisesProvider(
        muscle: widget.musclePrimary,
        equipment: widget.userEquipment,
      ),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Text(
              'Swap exercise',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Failed to load alternatives: $e')),
              data: (exercises) {
                // Exclude current exercise from list
                final alternatives = exercises
                    .where((e) => e.slug != widget.currentExerciseSlug)
                    .toList();

                if (alternatives.isEmpty) {
                  return const Center(
                    child: Text('No alternatives available for this equipment.'),
                  );
                }

                return ListView.builder(
                  controller: scrollController,
                  itemCount: alternatives.length,
                  itemBuilder: (context, index) => _AlternativeRow(
                    exercise: alternatives[index],
                    onTap: _swapping
                        ? null
                        : () => _swap(alternatives[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _swap(ExerciseModel exercise) async {
    setState(() => _swapping = true);
    try {
      final client = ref.read(tektoApiClientProvider);
      await client.post<void>(
        '/functions/v1/swap-exercise',
        data: {
          'plan_exercise_id': widget.planExerciseId,
          'new_exercise_id': exercise.id,
        },
      );
      if (mounted) Navigator.of(context).pop(exercise);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Swap failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _swapping = false);
    }
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({
    required this.exercise,
    required this.onTap,
  });
  final ExerciseModel exercise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: exercise.videoFrontUrl != null
            ? _VideoThumbnail(url: exercise.videoFrontUrl!)
            : const Icon(Icons.fitness_center),
        title: Text(exercise.nameEn),
        subtitle: Text(exercise.musclePrimary.join(', ')),
        onTap: onTap,
        trailing: onTap == null
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.swap_horiz, color: AppColors.accent),
      );
}

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.charcoalElevated,
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
        child: const Icon(Icons.play_circle_outline,
            color: AppColors.onDarkSecondary),
      );
}
