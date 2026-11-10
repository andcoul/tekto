// Starting weights (T113; US1 scenario 3, FR-009). Conservative by design: the first sessions
// should feel easy, and weekly adaptation (US5) progresses from there.
import type { LibraryExercise } from './plan-draft.ts';
import type { StrengthEstimates, StrengthLift, TrainingLevel } from './types.ts';

/** Reps kept in reserve when converting an e1RM into a working weight (≈ RPE 7). */
const RESERVE_REPS = 3;

/**
 * Exercise → the strength-check lift it scales from, and the fraction of that lift's e1RM.
 * Dumbbell ratios are per hand. Exercises not listed use level defaults.
 */
const RATIOS: Record<string, { lift: StrengthLift; ratio: number }> = {
  'barbell-squat': { lift: 'squat', ratio: 1.0 },
  'goblet-squat': { lift: 'squat', ratio: 0.35 },
  'dumbbell-lunge': { lift: 'squat', ratio: 0.15 },
  'bench-press': { lift: 'bench_press', ratio: 1.0 },
  'dumbbell-bench-press': { lift: 'bench_press', ratio: 0.35 },
  'overhead-press': { lift: 'bench_press', ratio: 0.6 },
  'dumbbell-shoulder-press': { lift: 'bench_press', ratio: 0.22 },
  'barbell-row': { lift: 'bench_press', ratio: 0.7 },
  'dumbbell-row': { lift: 'bench_press', ratio: 0.3 },
  'lat-pulldown': { lift: 'bench_press', ratio: 0.65 },
  'deadlift': { lift: 'deadlift', ratio: 1.0 },
  'romanian-deadlift': { lift: 'deadlift', ratio: 0.6 },
  'hip-thrust': { lift: 'deadlift', ratio: 0.8 },
};

type Kind = 'barbell' | 'dumbbell' | 'cable' | 'bodyweight';

/** Conservative defaults when the lift was not estimated. */
const DEFAULTS: Record<Kind, Record<TrainingLevel, number>> = {
  barbell: { beginner: 20, intermediate: 40, advanced: 60 },
  dumbbell: { beginner: 4, intermediate: 10, advanced: 16 },
  cable: { beginner: 15, intermediate: 30, advanced: 45 },
  bodyweight: { beginner: 0, intermediate: 0, advanced: 0 },
};

const INCREMENT: Record<Kind, number> = { barbell: 2.5, dumbbell: 1, cable: 2.5, bodyweight: 0 };
const EMPTY_BAR_KG = 20;

function kindOf(ex: LibraryExercise): Kind {
  if (ex.equipment.includes('barbell')) return 'barbell';
  if (ex.equipment.includes('dumbbell')) return 'dumbbell';
  if (ex.equipment.some((e) => e === 'cable' || e === 'machine' || e === 'bands')) return 'cable';
  return 'bodyweight';
}

const e1rm = (weightKg: number, reps: number) => weightKg * (1 + reps / 30);

export function startingWeightKg(
  ex: LibraryExercise,
  reps: { reps_min: number; reps_max: number },
  level: TrainingLevel,
  estimates: StrengthEstimates | null | undefined,
): number {
  const kind = kindOf(ex);
  if (kind === 'bodyweight') return 0;

  let weight = DEFAULTS[kind][level];
  const mapping = RATIOS[ex.slug];
  const estimate = mapping ? estimates?.[mapping.lift] : undefined;
  if (mapping && estimate && estimate.weight_kg > 0 && estimate.reps > 0) {
    const target = e1rm(estimate.weight_kg, estimate.reps) * mapping.ratio;
    weight = target / (1 + (reps.reps_max + RESERVE_REPS) / 30);
  }

  const step = INCREMENT[kind];
  const rounded = Math.floor(weight / step) * step;
  const floor = kind === 'barbell' ? EMPTY_BAR_KG : step;
  return Math.max(rounded, floor, 0);
}
