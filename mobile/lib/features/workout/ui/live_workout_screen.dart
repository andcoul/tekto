import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/video_player_widget.dart';
import '../../../shared/widgets/set_log_row.dart';
import '../../../shared/widgets/rest_timer_widget.dart';
import '../domain/workout_controller.dart';

class LiveWorkoutScreen extends ConsumerWidget {
  const LiveWorkoutScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(workoutControllerProvider);

    if (state.phase == WorkoutPhase.complete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/workout/$sessionId/summary');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmExit(context, ref),
        ),
        actions: [
          TextButton(
            onPressed: () => ref.read(workoutControllerProvider.notifier).completeWorkout(),
            child: const Text('Finish'),
          ),
        ],
      ),
      body: state.phase == WorkoutPhase.resting
          ? RestTimerWidget(
              seconds: state.restSecondsRemaining,
              onSkip: () =>
                  ref.read(workoutControllerProvider.notifier).skipRest(),
            )
          : _WorkoutContent(sessionId: sessionId),
    );
  }

  Future<void> _confirmExit(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End workout?'),
        content: const Text('Your logged sets will be saved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('End workout')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(workoutControllerProvider.notifier).completeWorkout();
    }
  }
}

class _WorkoutContent extends ConsumerWidget {
  const _WorkoutContent({required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In a production implementation, exercises are loaded from plan data.
    // This is the UI structure — wired to real data via plan_provider.
    return Column(
      children: [
        // Video player for current exercise
        VideoPlayerWidget(
          remoteUrl: null, // populated by real exercise data (T050)
          isPro: false,
          isOnline: ref.watch(isOnlineProvider).value ?? true,
          aspectRatio: 16 / 9,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Exercise name + muscle targets
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Current Exercise',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                onPressed: () => context.push('/form-check/exercise-slug'),
                tooltip: 'Form check (Pro)',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Technique cues
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CueBubble(text: 'Brace core and big breath before descending.'),
              _CueBubble(text: 'Push knees out in line with toes.'),
              _CueBubble(text: 'Drive through heels as you stand.'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Set rows
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            itemCount: 4, // replaced by real sets from plan data
            itemBuilder: (context, i) => SetLogRow(
              setNumber: i + 1,
              suggestedWeightKg: null,
              suggestedRepsMin: 6,
              suggestedRepsMax: 8,
              onLogged: (weight, reps, rpe) {
                // Log the set via controller
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CueBubble extends StatelessWidget {
  const _CueBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.charcoalElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}
