import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/exercise_model.dart';
import '../../library/domain/exercise_provider.dart';
import '../domain/swap_alternatives.dart';

/// Bottom sheet for swapping an exercise in the plan (FR-028, T087). Available to every tier.
/// Lists only alternatives the server accepts (see [swapAlternatives]) and calls
/// `swap-exercise` with the chosen slug. Pops with the chosen exercise on success.
class ExerciseSwapSheet extends ConsumerStatefulWidget {
  const ExerciseSwapSheet({
    super.key,
    required this.planExerciseId,
    required this.currentExerciseSlug,
    required this.userEquipment,
    required this.userLimitations,
  });

  final String planExerciseId;
  final String currentExerciseSlug;
  final List<String> userEquipment;
  final List<String> userLimitations;

  @override
  ConsumerState<ExerciseSwapSheet> createState() => _ExerciseSwapSheetState();
}

class _ExerciseSwapSheetState extends ConsumerState<ExerciseSwapSheet> {
  bool _swapping = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exercisesAsync = ref.watch(exercisesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Text(l10n.swapTitle, style: Theme.of(context).textTheme.titleLarge),
          ),
          const Divider(height: 1),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(child: Text(l10n.swapFailed)),
              data: (library) {
                final current = library.where((e) => e.slug == widget.currentExerciseSlug).firstOrNull;
                final alternatives = current == null
                    ? const <ExerciseModel>[]
                    : swapAlternatives(library,
                        current: current, equipment: widget.userEquipment, limitations: widget.userLimitations);
                if (alternatives.isEmpty) return Center(child: Text(l10n.swapNoAlternatives));
                return ListView.builder(
                  controller: scrollController,
                  itemCount: alternatives.length,
                  itemBuilder: (context, index) => _AlternativeRow(
                    exercise: alternatives[index],
                    onTap: _swapping ? null : () => _swap(alternatives[index]),
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
    final l10n = AppLocalizations.of(context);
    setState(() => _swapping = true);
    try {
      await ref.read(dioClientProvider).post<Map<String, dynamic>>(
        '/functions/v1/swap-exercise',
        data: {'plan_exercise_id': widget.planExerciseId, 'new_exercise_slug': exercise.slug},
      );
      if (mounted) Navigator.of(context).pop(exercise);
    } on DioException catch (e) {
      final code = (e.response?.data is Map) ? (e.response!.data as Map)['code'] : null;
      final message = switch (code) {
        'EXERCISE_NO_VIDEO' || 'EXERCISE_NOT_ALLOWED' || 'EXERCISE_NOT_EQUIVALENT' => l10n.swapNotAllowed,
        _ => l10n.swapFailed,
      };
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _swapping = false);
    }
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({required this.exercise, required this.onTap});
  final ExerciseModel exercise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    return ListTile(
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.charcoalElevated,
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
        child: const Icon(Icons.play_circle_outline, color: AppColors.onDarkSecondary),
      ),
      title: Text(fr ? exercise.nameFr : exercise.nameEn),
      subtitle: Text(exercise.musclePrimary.join(', ')),
      onTap: onTap,
      trailing: onTap == null
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.swap_horiz, color: AppColors.accent),
    );
  }
}
