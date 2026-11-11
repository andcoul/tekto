import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/weight_units.dart';
import '../domain/workout_controller.dart';
import '../domain/workout_providers.dart';

/// Workout summary (US2 acceptance scenario 4): total volume in the user's unit,
/// exercises completed, PRs hit, and the session effort rating (1–10).
class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({super.key, required this.sessionId, required this.workoutLogId});
  final String sessionId;

  /// From the route's `?log=` parameter; null sends the user home.
  final String? workoutLogId;

  @override
  ConsumerState<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  int _effortRating = 7;
  bool _saving = false;

  Future<void> _finish() async {
    final logId = widget.workoutLogId;
    final logs = ref.read(workoutLogRepositoryProvider);
    if (logId == null || logs == null) {
      context.go('/home');
      return;
    }
    setState(() => _saving = true);
    final summary = await ref.read(workoutSummaryProvider(logId).future);
    final finishedAt = await logs.finishWorkout(logId, effortRating: _effortRating, totalVolumeKg: summary.totalVolumeKg);
    final prefs = await ref.read(userPrefsProvider.future);

    // Fire and forget: the workout is saved; Health must never hold the user here (FR-012).
    unawaited(ref.read(healthSyncServiceProvider).syncFinishedWorkout(
          workoutLogId: logId,
          healthSyncEnabled: prefs.healthSyncEnabled,
          start: summary.startedAt,
          end: finishedAt,
        ));

    ref.read(workoutControllerProvider.notifier).reset();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final logId = widget.workoutLogId;
    final summary = logId == null ? null : ref.watch(workoutSummaryProvider(logId)).value;
    final unit = ref.watch(userPrefsProvider).value?.unit ?? 'kg';
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      appBar: AppBar(title: Text(l.workoutSummaryTitle), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(
                          label: l.workoutTotalVolume,
                          value: l.workoutVolumeValue(
                            NumberFormat.decimalPattern(locale).format(kgToUnit(summary.totalVolumeKg, unit).round()),
                            unit == 'lb' ? l.unitLb : l.unitKg,
                          ),
                        ),
                        _Stat(label: l.workoutSummaryExercises, value: '${summary.exercisesCompleted}'),
                        _Stat(label: l.workoutSummaryPrs, value: '${summary.prCount}', highlight: summary.prCount > 0),
                      ],
                    ),
                  ),
                )
              else if (logId != null)
                const Center(child: CircularProgressIndicator()),
              const SizedBox(height: AppSpacing.lg),
              Text(l.workoutEffortPrompt, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                SizedBox(
                  width: 96,
                  child: Text('$_effortRating ${l.workoutRpe}', style: theme.textTheme.headlineMedium),
                ),
                Expanded(
                  child: Slider(
                    key: const Key('effort-slider'),
                    value: _effortRating.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_effortRating',
                    activeColor: AppColors.accent,
                    onChanged: (v) => setState(() => _effortRating = v.round()),
                  ),
                ),
              ]),
              const Spacer(),
              SizedBox(
                height: AppSizes.minTapTarget,
                child: ElevatedButton(
                  onPressed: _saving ? null : _finish,
                  child: Text(l.workoutFinishShort),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: highlight ? AppColors.pr : null),
        ),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ]);
}
