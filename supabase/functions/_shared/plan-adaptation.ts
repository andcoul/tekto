// ---------------------------------------------------------------------------
// PlanAdaptationService
// ---------------------------------------------------------------------------
// Computes week-over-week progression events for a completed training week.
//
// Progression logic (per plan_exercise):
//   - PRIMARY PATH: all reps hit at or below rpe_target AND increment ≤ 10% e1RM
//     → increase suggested_weight_kg by equipment increment
//   - ALTERNATIVE PATH (US5 Scenario 1): increment would exceed 10% e1RM
//     → increase reps_max by 1 instead
//   - MAINTAIN: 2+ sessions missed in the week
//   - REDUCE: avg actual RPE > rpe_target + 1 → reduce by one increment
//
// Principle V: unit tested in plan-adaptation.test.ts

export interface SetLogRow {
  id: string;
  plan_exercise_id: string;
  weight_kg: number;
  reps: number;
  rpe_actual: number | null;
  workout_log_id: string;
}

export interface PlanExerciseRow {
  id: string;
  reps_min: number;
  reps_max: number;
  rpe_target: number;
  suggested_weight_kg: number | null;
  exercise_id: string;
  equipment: string; // 'barbell' | 'dumbbell' | ...
}

export interface AdaptationEvent {
  planExerciseId: string;
  field: 'suggested_weight_kg' | 'reps_max';
  oldValue: number;
  newValue: number;
  reasonEn: string;
  reasonFr: string;
}

export interface WeekData {
  planExercise: PlanExerciseRow;
  setLogs: SetLogRow[];
  /** Number of sessions in the plan for this week */
  plannedSessionCount: number;
  /** Number of sessions that were actually completed */
  completedSessionCount: number;
}

// Equipment-specific weight increments (kg)
const INCREMENT: Record<string, number> = {
  barbell: 2.5,
  dumbbell: 1.0,
  cable: 2.5,
  bodyweight: 0,
  default: 2.5,
};

export function computeAdaptation(weekData: WeekData[]): AdaptationEvent[] {
  const events: AdaptationEvent[] = [];

  for (const data of weekData) {
    const event = computeForExercise(data);
    if (event) events.push(event);
  }

  return events;
}

function computeForExercise(data: WeekData): AdaptationEvent | null {
  const { planExercise, setLogs, plannedSessionCount, completedSessionCount } = data;
  const missedSessions = plannedSessionCount - completedSessionCount;

  // ---- MAINTAIN: 2+ sessions missed ----
  if (missedSessions >= 2) {
    return null; // No change — maintain current weight
  }

  if (setLogs.length === 0) {
    // Edge case: session was "completed" but no sets were logged
    return null;
  }

  // ---- Compute averages ----
  const avgRpe = setLogs.reduce((sum, s) => sum + (s.rpe_actual ?? planExercise.rpe_target), 0) / setLogs.length;
  const allRepsHit = setLogs.every((s) => s.reps >= planExercise.reps_min);
  const currentWeight = planExercise.suggested_weight_kg ?? 20;

  // ---- REDUCE: avg RPE > rpe_target + 1 ----
  if (avgRpe > planExercise.rpe_target + 1) {
    const increment = getIncrement(planExercise.equipment);
    if (increment === 0) return null;
    const newWeight = Math.max(0, currentWeight - increment);
    return {
      planExerciseId: planExercise.id,
      field: 'suggested_weight_kg',
      oldValue: currentWeight,
      newValue: newWeight,
      reasonEn: `Average RPE (${avgRpe.toFixed(1)}) exceeded your target by more than 1 — weight reduced slightly.`,
      reasonFr: `RPE moyen (${avgRpe.toFixed(1)}) dépassé la cible de plus de 1 — poids légèrement réduit.`,
    };
  }

  // ---- PROGRESS: all reps hit at or below rpe_target ----
  if (allRepsHit && avgRpe <= planExercise.rpe_target) {
    const increment = getIncrement(planExercise.equipment);
    if (increment === 0) return null;

    // Estimate 1RM from last set
    const lastSet = setLogs[setLogs.length - 1];
    const e1rm = lastSet.weight_kg * (1 + lastSet.reps / 30.0);
    const incrementPercent = increment / e1rm;

    // PRIMARY PATH: increment ≤ 10% of e1RM
    if (incrementPercent <= 0.1) {
      const newWeight = currentWeight + increment;
      return {
        planExerciseId: planExercise.id,
        field: 'suggested_weight_kg',
        oldValue: currentWeight,
        newValue: newWeight,
        reasonEn: `You nailed your target reps at RPE ${avgRpe.toFixed(1)} — time to progress the weight.`,
        reasonFr: `Objectif de reps atteint à RPE ${avgRpe.toFixed(1)} — progression du poids.`,
      };
    }

    // ALTERNATIVE PATH: increment > 10% of e1RM → increase reps_max instead
    const newRepsMax = planExercise.reps_max + 1;
    return {
      planExerciseId: planExercise.id,
      field: 'reps_max',
      oldValue: planExercise.reps_max,
      newValue: newRepsMax,
      reasonEn: `Weight jump would be too large — adding a rep to build more volume first.`,
      reasonFr: `La progression en poids serait trop importante — ajout d'une répétition pour plus de volume.`,
    };
  }

  return null; // maintain
}

function getIncrement(equipment: string): number {
  return INCREMENT[equipment] ?? INCREMENT.default;
}
