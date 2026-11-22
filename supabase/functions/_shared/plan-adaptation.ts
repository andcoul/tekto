// ---------------------------------------------------------------------------
// PlanAdaptationService (FR-026, Constitution V — tested in plan-adaptation.test.ts, T080)
// ---------------------------------------------------------------------------
// Computes next week's change for each plan exercise from one reviewed training week.
// The service decides every change; the explanation model only words them (ai-services §2b).
//
// Per plan exercise, in order:
//   1. no sets logged (session skipped or empty)                      → no change
//   2. too hard: avg set RPE, or the session's effort rating, above
//      target + 1 — or every set below reps_min                      → one load increment down
//      (bodyweight: held)
//   3. 2+ sessions of the week missed                                 → no change (never progress)
//   4. all reps hit at or below the target RPE
//        bodyweight                                                  → reps_max + 1
//        increment ≤ 10 % of e1RM                                    → load + one increment
//        otherwise                                                   → reps_max + 1
//   5. anything else                                                  → no change
// The target RPE is `rpe_target`, or 10 − `rir_target` when the plan uses RIR (FR-007).

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
  rpe_target: number | null;
  rir_target: number | null;
  suggested_weight_kg: number | null;
  exercise_slug: string;
  /** The exercise's equipment tags (exercises.equipment). */
  equipment: string[];
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
  /** Sessions scheduled in the reviewed week. */
  plannedSessionCount: number;
  /** Sessions of that week with a finished workout log; skipped ones are missed. */
  completedSessionCount: number;
  /** Effort rating (1–10) of the workout that contained this exercise, if given. */
  sessionEffort: number | null;
}

/** Load step per equipment (kg); bodyweight and bands progress by reps. */
const INCREMENT: Record<string, number> = {
  barbell: 2.5,
  cable: 2.5,
  machine: 2.5,
  smith_machine: 2.5,
  trap_bar: 2.5,
  dumbbell: 1.0, // kettlebells are tagged dumbbell (FR-001)
  bands: 0,
  suspension: 0,
};
const DEFAULT_INCREMENT = 2.5;
const DEFAULT_RPE_TARGET = 8;
const MAX_INCREMENT_SHARE_OF_E1RM = 0.1;

export function targetRpe(pe: Pick<PlanExerciseRow, 'rpe_target' | 'rir_target'>): number {
  if (pe.rpe_target !== null) return pe.rpe_target;
  if (pe.rir_target !== null) return 10 - pe.rir_target;
  return DEFAULT_RPE_TARGET;
}

export function loadIncrement(equipment: string[]): number {
  // A bodyweight move on a bar, bench or machine still progresses by reps (T157).
  if (equipment.includes('bodyweight')) return 0;
  for (const tag of equipment) if (tag in INCREMENT) return INCREMENT[tag];
  return DEFAULT_INCREMENT;
}

export function computeAdaptation(weekData: WeekData[]): AdaptationEvent[] {
  return weekData.map(computeForExercise).filter((e): e is AdaptationEvent => e !== null);
}

const fmt = (n: number) => (Number.isInteger(n) ? String(n) : n.toFixed(1));
const fmtFr = (n: number) => fmt(n).replace('.', ',');

function computeForExercise(data: WeekData): AdaptationEvent | null {
  const { planExercise: pe, setLogs, plannedSessionCount, completedSessionCount, sessionEffort } = data;
  if (setLogs.length === 0) return null;

  const target = targetRpe(pe);
  const rated = setLogs.filter((s) => s.rpe_actual !== null);
  const avgRpe = rated.length ? rated.reduce((sum, s) => sum + s.rpe_actual!, 0) / rated.length : null;
  const increment = loadIncrement(pe.equipment);
  const lastSet = setLogs[setLogs.length - 1];
  const currentWeight = pe.suggested_weight_kg ?? lastSet.weight_kg;

  // ---- 2. Too hard, or every set failed → one increment down ----
  const setsTooHard = avgRpe !== null && avgRpe > target + 1;
  const sessionTooHard = sessionEffort !== null && sessionEffort > target + 1;
  const allFailed = setLogs.every((s) => s.reps < pe.reps_min);
  if (setsTooHard || sessionTooHard || allFailed) {
    if (increment === 0) return null; // bodyweight: hold
    const newWeight = Math.max(0, currentWeight - increment);
    if (newWeight === currentWeight) return null;
    const [reasonEn, reasonFr] = allFailed && !setsTooHard && !sessionTooHard
      ? [
        `Every set fell short of ${pe.reps_min} reps — the weight comes down slightly so you can hit your reps.`,
        `Aucune série n'a atteint ${pe.reps_min} répétitions — la charge baisse légèrement pour vous permettre de les atteindre.`,
      ]
      : setsTooHard
      ? [
        `Your average RPE (${fmt(avgRpe!)}) was more than 1 above the target of ${fmt(target)} — the weight comes down slightly.`,
        `Votre RPE moyen (${fmtFr(avgRpe!)}) a dépassé la cible de ${fmtFr(target)} de plus de 1 — la charge baisse légèrement.`,
      ]
      : [
        `You rated this session too hard — the weight comes down slightly next week.`,
        `Vous avez trouvé cette séance trop dure — la charge baisse légèrement la semaine prochaine.`,
      ];
    return { planExerciseId: pe.id, field: 'suggested_weight_kg', oldValue: currentWeight, newValue: newWeight, reasonEn, reasonFr };
  }

  // ---- 3. Missed sessions: never progress ----
  if (plannedSessionCount - completedSessionCount >= 2) return null;

  // ---- 4. Progress ----
  const allRepsHit = setLogs.every((s) => s.reps >= pe.reps_min);
  if (!allRepsHit || (avgRpe ?? target) > target) return null;

  const repsEvent = (en: string, fr: string): AdaptationEvent => ({
    planExerciseId: pe.id,
    field: 'reps_max',
    oldValue: pe.reps_max,
    newValue: pe.reps_max + 1,
    reasonEn: en,
    reasonFr: fr,
  });

  if (increment === 0) {
    return repsEvent(
      `You hit every rep at or below RPE ${fmt(target)} — one more rep next week.`,
      `Toutes vos répétitions à RPE ${fmtFr(target)} ou moins — une répétition de plus la semaine prochaine.`,
    );
  }

  const e1rm = lastSet.weight_kg * (1 + lastSet.reps / 30);
  if (e1rm > 0 && increment / e1rm <= MAX_INCREMENT_SHARE_OF_E1RM) {
    return {
      planExerciseId: pe.id,
      field: 'suggested_weight_kg',
      oldValue: currentWeight,
      newValue: currentWeight + increment,
      reasonEn: `You hit every rep at or below RPE ${fmt(target)} — time to add ${fmt(increment)} kg.`,
      reasonFr: `Toutes vos répétitions à RPE ${fmtFr(target)} ou moins — on ajoute ${fmtFr(increment)} kg.`,
    };
  }
  return repsEvent(
    `A ${fmt(increment)} kg jump would be more than 10 % of your estimated max — one more rep first.`,
    `Un saut de ${fmtFr(increment)} kg dépasserait 10 % de votre max estimé — une répétition de plus d'abord.`,
  );
}
