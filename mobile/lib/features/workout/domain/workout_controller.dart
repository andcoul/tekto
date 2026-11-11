import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'live_session.dart';

part 'workout_controller.g.dart';

enum WorkoutPhase { idle, active, resting, complete }

/// Rest-timer bounds for the in-workout ±15 s adjustment (FR-008).
const kRestStepSec = 15;
const kRestMinSec = 15;
const kRestMaxSec = 600;

class WorkoutState {
  const WorkoutState({
    this.phase = WorkoutPhase.idle,
    this.workoutLogId,
    this.sessionId,
    this.currentExerciseIndex = 0,
    this.restSecondsRemaining = 0,
    this.isWorkoutActive = false,
    this.logged = const {},
  });

  final WorkoutPhase phase;
  final String? workoutLogId;
  final String? sessionId;
  final int currentExerciseIndex;
  final int restSecondsRemaining;

  /// True from start until the workout is completed; the paywall reads this so it
  /// never interrupts a workout (FR-030).
  final bool isWorkoutActive;

  /// Sets saved so far, keyed by `plan_exercises.id`, in logging order.
  final Map<String, List<LoggedSet>> logged;

  List<LoggedSet> setsFor(String planExerciseId) => logged[planExerciseId] ?? const [];

  WorkoutState copyWith({
    WorkoutPhase? phase,
    String? workoutLogId,
    String? sessionId,
    int? currentExerciseIndex,
    int? restSecondsRemaining,
    bool? isWorkoutActive,
    Map<String, List<LoggedSet>>? logged,
  }) =>
      WorkoutState(
        phase: phase ?? this.phase,
        workoutLogId: workoutLogId ?? this.workoutLogId,
        sessionId: sessionId ?? this.sessionId,
        currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
        restSecondsRemaining: restSecondsRemaining ?? this.restSecondsRemaining,
        isWorkoutActive: isWorkoutActive ?? this.isWorkoutActive,
        logged: logged ?? this.logged,
      );
}

@riverpod
class WorkoutController extends _$WorkoutController {
  Timer? _restTimer;

  @override
  WorkoutState build() {
    ref.onDispose(() => _restTimer?.cancel());
    return const WorkoutState();
  }

  /// Starts (or resumes, with [existing] sets) the workout [workoutLogId].
  void startWorkout({
    required String workoutLogId,
    required String sessionId,
    List<LoggedSet> existing = const [],
    int currentExerciseIndex = 0,
  }) {
    _restTimer?.cancel();
    final logged = <String, List<LoggedSet>>{};
    for (final s in existing) {
      (logged[s.planExerciseId] ??= []).add(s);
    }
    state = WorkoutState(
      phase: WorkoutPhase.active,
      workoutLogId: workoutLogId,
      sessionId: sessionId,
      currentExerciseIndex: currentExerciseIndex,
      isWorkoutActive: true,
      logged: logged,
    );
  }

  /// Records a saved set; starts the rest timer when [restSec] is given.
  void recordSet(LoggedSet set, {int? restSec}) {
    final logged = {...state.logged, set.planExerciseId: [...state.setsFor(set.planExerciseId), set]};
    _restTimer?.cancel();
    if (restSec == null || restSec <= 0) {
      state = state.copyWith(logged: logged, phase: WorkoutPhase.active, restSecondsRemaining: 0);
      return;
    }
    state = state.copyWith(logged: logged, phase: WorkoutPhase.resting, restSecondsRemaining: restSec);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Changes the running rest by [deltaSec], kept within 15–600 s. Affects this rest only.
  void adjustRest(int deltaSec) {
    if (state.phase != WorkoutPhase.resting) return;
    final next = (state.restSecondsRemaining + deltaSec).clamp(kRestMinSec, kRestMaxSec);
    state = state.copyWith(restSecondsRemaining: next);
  }

  void skipRest() {
    _restTimer?.cancel();
    state = state.copyWith(phase: WorkoutPhase.active, restSecondsRemaining: 0);
  }

  void goToExercise(int index) {
    if (index < 0) return;
    state = state.copyWith(currentExerciseIndex: index);
  }

  void completeWorkout() {
    _restTimer?.cancel();
    state = state.copyWith(phase: WorkoutPhase.complete, isWorkoutActive: false, restSecondsRemaining: 0);
  }

  /// Clears the finished workout so the next one starts fresh.
  void reset() {
    _restTimer?.cancel();
    state = const WorkoutState();
  }

  void _tick() {
    if (state.restSecondsRemaining <= 1) {
      _restTimer?.cancel();
      state = state.copyWith(phase: WorkoutPhase.active, restSecondsRemaining: 0);
    } else {
      state = state.copyWith(restSecondsRemaining: state.restSecondsRemaining - 1);
    }
  }
}
