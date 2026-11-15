import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/rest_timer_widget.dart';
import '../../../shared/widgets/set_log_row.dart';
import '../../../shared/models/exercise_model.dart';
import '../../../shared/utils/weight_units.dart';
import '../../../shared/widgets/video_player_widget.dart';
import '../../plan/domain/plan_provider.dart';
import '../../plan/ui/exercise_swap_sheet.dart';
import 'plate_calculator_sheet.dart';
import '../../subscription/domain/entitlement_provider.dart';
import '../domain/live_session.dart';
import '../domain/workout_controller.dart';
import '../domain/workout_providers.dart';

/// Live workout (US2). Everything on this screen works offline for every user
/// (Constitution I): the session comes from the device cache and every write goes
/// through the sync queue. One primary action is visible at a time (Constitution VI):
/// the current set's "Done", "Skip rest", "Next exercise" or "Finish workout".
class LiveWorkoutScreen extends ConsumerStatefulWidget {
  const LiveWorkoutScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends ConsumerState<LiveWorkoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureStarted());
  }

  /// Resumes the unfinished workout for this session, or starts a new one.
  Future<void> _ensureStarted() async {
    final current = ref.read(workoutControllerProvider);
    if (current.sessionId == widget.sessionId && current.workoutLogId != null && current.phase != WorkoutPhase.complete) {
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    final logs = ref.read(workoutLogRepositoryProvider);
    if (userId == null || logs == null) return;

    final session = await ref.read(liveSessionProvider(widget.sessionId).future);
    final open = await ref.read(workoutSessionRepositoryProvider).findOpenLog(userId: userId, sessionId: widget.sessionId);
    if (!mounted) return;

    final controller = ref.read(workoutControllerProvider.notifier);
    if (open != null) {
      final counts = <String, int>{};
      for (final s in open.sets) {
        counts[s.planExerciseId] = (counts[s.planExerciseId] ?? 0) + 1;
      }
      final firstUnfinished = session.exercises.indexWhere((e) => (counts[e.planExerciseId] ?? 0) < e.sets);
      controller.startWorkout(
        workoutLogId: open.workoutLogId,
        sessionId: widget.sessionId,
        existing: open.sets,
        currentExerciseIndex: firstUnfinished < 0 ? session.exercises.length - 1 : firstUnfinished,
      );
    } else {
      final id = await logs.startWorkout(widget.sessionId);
      if (!mounted) return;
      controller.startWorkout(workoutLogId: id, sessionId: widget.sessionId);
    }
  }

  Future<void> _logSet(LiveSession session, LiveExercise ex, int setNumber, double kg, int reps, double? rpe) async {
    final state = ref.read(workoutControllerProvider);
    final logId = state.workoutLogId;
    if (logId == null) return;

    final saved = await ref.read(setLogRepositoryProvider).logSet(
          workoutLogId: logId,
          planExerciseId: ex.planExerciseId,
          exerciseSlug: ex.slug,
          setNumber: setNumber,
          weightKg: kg,
          reps: reps,
          rpeActual: rpe,
          userId: ref.read(currentUserIdProvider),
        );
    if (!mounted) return;

    // Rest after every set except the last one of the whole workout (FR-008).
    final workoutDone = session.exercises.every((e) {
      final logged = state.setsFor(e.planExerciseId).length + (e.planExerciseId == ex.planExerciseId ? 1 : 0);
      return logged >= e.sets;
    });
    ref.read(workoutControllerProvider.notifier).recordSet(saved, restSec: workoutDone ? null : ex.restSec);
  }

  void _finish() {
    final logId = ref.read(workoutControllerProvider).workoutLogId;
    ref.read(workoutControllerProvider.notifier).completeWorkout();
    if (logId == null) {
      context.go('/home');
      return;
    }
    context.go('/workout/${widget.sessionId}/summary?log=$logId');
  }

  Future<void> _confirmEnd() async {
    final l = AppLocalizations.of(context);
    final end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.workoutEndTitle),
        content: Text(l.workoutEndBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.workoutKeepGoing)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.workoutEnd)),
        ],
      ),
    );
    if (end == true && mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final sessionAsync = ref.watch(liveSessionProvider(widget.sessionId));
    final state = ref.watch(workoutControllerProvider);

    // Haptic when a rest runs out on its own (not on "Skip rest").
    ref.listen(workoutControllerProvider, (prev, next) {
      if (prev?.phase == WorkoutPhase.resting && next.phase == WorkoutPhase.active && prev!.restSecondsRemaining <= 1) {
        HapticFeedback.mediumImpact();
      }
    });

    final session = sessionAsync.value;
    // Wait for the unit preference too, so weights are never pre-filled in the wrong unit.
    final prefsLoaded = ref.watch(userPrefsProvider).hasValue;
    final ready = session != null && prefsLoaded && state.sessionId == widget.sessionId && state.workoutLogId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.name(lang) ?? l.workoutTitle),
        leading: IconButton(icon: const Icon(Icons.close), tooltip: l.workoutEnd, onPressed: _confirmEnd),
        actions: [TextButton(onPressed: ready ? _finish : null, child: Text(l.workoutFinishShort))],
      ),
      body: SafeArea(
        child: switch (sessionAsync) {
          AsyncError(:final error) => Center(child: Text('$error')),
          _ when !ready || session.exercises.isEmpty => const Center(child: CircularProgressIndicator()),
          _ => _body(context, l, lang, session, state),
        },
      ),
    );
  }

  /// 7.0 → "7", 7.5 → "7.5".
  static String _rpe(num v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  /// Plate calculator for the current set's weight, in the user's unit (FR-042). A bottom sheet,
  /// never a dialog over the set (Constitution VI).
  void _openPlates(LiveExercise ex, String unit) {
    final weight = kgToUnit(ex.suggestedWeightKg ?? 0, unit);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PlateCalculatorSheet(initialWeight: weight, unit: unit),
    );
  }

  /// Opens the swap sheet; on success refreshes the cached plan and reloads this session.
  Future<void> _openSwap(String planExerciseId, String slug) async {
    final prefs = ref.read(userPrefsProvider).value ?? const UserPrefs();
    final chosen = await showModalBottomSheet<ExerciseModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExerciseSwapSheet(
        planExerciseId: planExerciseId,
        currentExerciseSlug: slug,
        userEquipment: prefs.equipment,
        userLimitations: prefs.limitations,
      ),
    );
    if (chosen == null || !mounted) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      try {
        await ref.read(planRepositoryProvider).refreshActivePlan(userId);
      } on Object {
        // Swap is applied on the server; the cache catches up on the next refresh.
      }
    }
    ref.invalidate(liveSessionProvider(widget.sessionId));
  }

  Widget _body(BuildContext context, AppLocalizations l, String lang, LiveSession session, WorkoutState state) {
    final index = state.currentExerciseIndex.clamp(0, session.exercises.length - 1);
    final ex = session.exercises[index];
    final logged = state.setsFor(ex.planExerciseId);
    final exerciseComplete = logged.length >= ex.sets;
    final isLast = index == session.exercises.length - 1;
    final resting = state.phase == WorkoutPhase.resting;
    final unit = ref.watch(userPrefsProvider).value?.unit ?? 'kg';
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;
    // Unknown connectivity is treated as offline: never block on the network.
    final isOnline = ref.watch(isOnlineProvider).value ?? false;
    final controller = ref.read(workoutControllerProvider.notifier);
    final last = logged.isEmpty ? null : logged.last;

    return Column(children: [
      VideoPlayerWidget(
        key: ValueKey('video-${ex.slug}'),
        isPro: isPro,
        isOnline: isOnline,
        localPath: ex.localVideoPath,
        remoteUrl: ex.videoUrl,
        remoteCaptions: ex.captions,
        localCaptions: ex.localCaptions,
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l.workoutPreviousExercise,
                onPressed: index > 0 ? () => controller.goToExercise(index - 1) : null,
              ),
              Expanded(
                child: Column(children: [
                  Text(ex.name(lang), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  Text(l.workoutExerciseOf(index + 1, session.exercises.length),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onDarkSecondary)),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l.workoutNextExercise,
                onPressed: isLast ? null : () => controller.goToExercise(index + 1),
              ),
              // Swap before the first set only (FR-028, every tier); it needs the server.
              if (logged.isEmpty)
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: l.swapTitle,
                  onPressed: isOnline ? () => _openSwap(ex.planExerciseId, ex.slug) : null,
                ),
              if (ex.usesBarbell)
                IconButton(
                  icon: const Icon(Icons.calculate_outlined),
                  tooltip: l.platesTitle,
                  onPressed: () => _openPlates(ex, unit),
                ),
              if (ex.formCheckSupported)
                IconButton(
                  icon: const Icon(Icons.videocam_outlined),
                  tooltip: l.workoutFormCheck,
                  onPressed: () => context.push('/form-check/${ex.slug}'),
                ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            // Same line as the set counter so the logged rows (and their PR badges) stay on screen.
            Row(children: [
              Expanded(
                child: Text(
                  l.workoutSetOf((logged.length + 1).clamp(1, ex.sets), ex.sets),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // Effort target (FR-007): RIR targets also show the RPE they correspond to.
              if (ex.rirTarget case final rir?)
                Text(l.workoutTargetRir(rir, _rpe(10 - rir)), key: const Key('effort-target'))
              else if (ex.rpeTarget case final rpe?)
                Text(l.workoutTargetRpe(_rpe(rpe)), key: const Key('effort-target')),
            ]),
            const SizedBox(height: AppSpacing.sm),
            for (final cue in ex.keyCues(lang)) _CueBubble(text: cue),
            const SizedBox(height: AppSpacing.sm),
            for (var n = 1; n <= ex.sets; n++)
              _row(session, ex, n, logged, unit, resting, last),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.base),
        child: resting
            ? RestTimerWidget(
                secondsRemaining: state.restSecondsRemaining,
                onSkip: controller.skipRest,
                onAdjust: controller.adjustRest,
              )
            : exerciseComplete
                ? SizedBox(
                    width: double.infinity,
                    height: AppSizes.minTapTarget,
                    child: ElevatedButton(
                      onPressed: isLast ? _finish : () => controller.goToExercise(index + 1),
                      child: Text(isLast ? l.workoutFinish : l.workoutNextExercise),
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _row(LiveSession session, LiveExercise ex, int n, List<LoggedSet> logged, String unit, bool resting, LoggedSet? last) {
    final key = ValueKey('set-${ex.planExerciseId}-$n');
    if (n <= logged.length) {
      final s = logged[n - 1];
      return SetLogRow(
        key: key,
        setNumber: n,
        mode: SetRowMode.done,
        unit: unit,
        repsMin: ex.repsMin,
        repsMax: ex.repsMax,
        loggedWeightKg: s.weightKg,
        loggedReps: s.reps,
        loggedRpe: s.rpe,
        isPr: s.isPr,
      );
    }
    final isCurrent = n == logged.length + 1 && !resting;
    return SetLogRow(
      key: key,
      setNumber: n,
      mode: isCurrent ? SetRowMode.current : SetRowMode.upcoming,
      unit: unit,
      repsMin: ex.repsMin,
      repsMax: ex.repsMax,
      // The next set starts from what was just lifted, else the plan's suggestion (FR-009).
      prefillWeightKg: last?.weightKg ?? ex.suggestedWeightKg,
      prefillReps: last?.reps,
      onDone: isCurrent ? (kg, reps, rpe) => _logSet(session, ex, n, kg, reps, rpe) : null,
    );
  }
}

class _CueBubble extends StatelessWidget {
  const _CueBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(color: AppColors.charcoalElevated, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      );
}
