import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workout_controller.g.dart';

enum WorkoutPhase { idle, active, resting, complete }

class WorkoutState {
  const WorkoutState({
    this.phase = WorkoutPhase.idle,
    this.workoutLogId,
    this.sessionId,
    this.currentExerciseIndex = 0,
    this.currentSetIndex = 0,
    this.restSecondsRemaining = 0,
    this.isWorkoutActive = false,
    this.newPrExerciseSlug,
  });

  final WorkoutPhase phase;
  final String? workoutLogId;
  final String? sessionId;
  final int currentExerciseIndex;
  final int currentSetIndex;
  final int restSecondsRemaining;
  final bool isWorkoutActive;
  final String? newPrExerciseSlug; // non-null while PR animation is showing

  WorkoutState copyWith({
    WorkoutPhase? phase,
    String? workoutLogId,
    String? sessionId,
    int? currentExerciseIndex,
    int? currentSetIndex,
    int? restSecondsRemaining,
    bool? isWorkoutActive,
    String? newPrExerciseSlug,
    bool clearPr = false,
  }) =>
      WorkoutState(
        phase: phase ?? this.phase,
        workoutLogId: workoutLogId ?? this.workoutLogId,
        sessionId: sessionId ?? this.sessionId,
        currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
        currentSetIndex: currentSetIndex ?? this.currentSetIndex,
        restSecondsRemaining: restSecondsRemaining ?? this.restSecondsRemaining,
        isWorkoutActive: isWorkoutActive ?? this.isWorkoutActive,
        newPrExerciseSlug: clearPr ? null : (newPrExerciseSlug ?? this.newPrExerciseSlug),
      );
}

@riverpod
class WorkoutController extends _$WorkoutController {
  Timer? _restTimer;

  @override
  WorkoutState build() => const WorkoutState();

  void startWorkout({
    required String workoutLogId,
    required String sessionId,
  }) {
    state = state.copyWith(
      phase: WorkoutPhase.active,
      workoutLogId: workoutLogId,
      sessionId: sessionId,
      currentExerciseIndex: 0,
      currentSetIndex: 0,
      isWorkoutActive: true,
    );
  }

  void setCompleted({required int restSec, String? prExerciseSlug}) {
    _restTimer?.cancel();

    state = state.copyWith(
      phase: WorkoutPhase.resting,
      restSecondsRemaining: restSec,
      newPrExerciseSlug: prExerciseSlug,
    );

    _startRestTimer(restSec);
  }

  void skipRest() {
    _restTimer?.cancel();
    state = state.copyWith(
      phase: WorkoutPhase.active,
      restSecondsRemaining: 0,
      currentSetIndex: state.currentSetIndex + 1,
    );
  }

  void nextExercise() {
    state = state.copyWith(
      phase: WorkoutPhase.active,
      currentExerciseIndex: state.currentExerciseIndex + 1,
      currentSetIndex: 0,
      clearPr: true,
    );
  }

  void completeWorkout() {
    _restTimer?.cancel();
    state = state.copyWith(
      phase: WorkoutPhase.complete,
      isWorkoutActive: false,
    );
  }

  void _startRestTimer(int seconds) {
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.restSecondsRemaining <= 1) {
        timer.cancel();
        state = state.copyWith(
          phase: WorkoutPhase.active,
          restSecondsRemaining: 0,
          currentSetIndex: state.currentSetIndex + 1,
        );
      } else {
        state = state.copyWith(
          restSecondsRemaining: state.restSecondsRemaining - 1,
        );
      }
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }
}
