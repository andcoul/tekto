// Plan rule-checker (T015) — one validator for AI and template plans (FR-002a, Constitution III/IV).
// Pure: takes the exercise library as input so it can be unit-tested without a database.
import { isAllowed } from './exercise-substitution.ts';
import {
  type DraftPlan,
  estimateSessionMinutes,
  type Library,
  type LibraryExercise,
  libraryFrom,
  type PlanProfile,
  type PlanSource,
  type ValidationError,
  type ValidationResult,
} from './plan-draft.ts';
import type { TrainingLevel } from './types.ts';

export type { ValidationError, ValidationResult };

/** Weekly working sets per primary muscle (contracts/ai-services.md §1 rule 2). */
export const VOLUME_BOUNDS: Record<TrainingLevel, { min: number; max: number }> = {
  beginner: { min: 10, max: 14 },
  intermediate: { min: 14, max: 18 },
  advanced: { min: 16, max: 22 },
};

/**
 * Muscles whose minimum is enforced. Smaller muscles only have a maximum, because a sound plan
 * often trains them indirectly. Minimums apply only at 3+ days per week.
 */
export const MAJOR_MUSCLES = new Set(['chest', 'lats', 'quadriceps', 'hamstrings', 'glutes', 'shoulders']);

export const DURATION_BUFFER_MIN = 10;

export function validatePlan(
  plan: DraftPlan,
  profile: PlanProfile,
  library: Library,
  source: PlanSource,
): ValidationResult {
  const errors: ValidationError[] = [];

  if (plan.weeks_total < 4 || plan.weeks_total > 12) {
    errors.push({ code: 'WEEKS', message: `weeks_total ${plan.weeks_total} is outside 4–12.` });
  }

  // Per-exercise rules: library membership, Video Gate, equipment, limitations.
  const reported = new Set<string>();
  for (const session of plan.sessions) {
    for (const pe of session.exercises) {
      if (reported.has(pe.exercise_slug)) continue;
      reported.add(pe.exercise_slug);
      const ex = library.get(pe.exercise_slug);
      if (!ex) {
        errors.push({ code: 'UNKNOWN_EXERCISE', exercise_slug: pe.exercise_slug, message: `'${pe.exercise_slug}' is not in the library.` });
      } else if (!ex.video_front_url) {
        errors.push({ code: 'VIDEO_GATE', exercise_slug: ex.slug, message: `'${ex.slug}' has no video_front_url.` });
      } else if (!isAllowed({ ...ex, contraindications: [] }, profile)) {
        errors.push({ code: 'EQUIPMENT', exercise_slug: ex.slug, message: `'${ex.slug}' needs equipment the user does not have.` });
      } else if (!isAllowed(ex, profile)) {
        errors.push({ code: 'CONTRAINDICATED', exercise_slug: ex.slug, message: `'${ex.slug}' is contraindicated by the user's limitations.` });
      }
    }
  }

  // Rest days: no two consecutive days in a week that train the same primary muscle.
  for (const [week, sessions] of byWeek(plan)) {
    const sorted = [...sessions].sort((a, b) => a.day_of_week - b.day_of_week);
    for (let i = 1; i < sorted.length; i++) {
      const prev = sorted[i - 1];
      const cur = sorted[i];
      if (cur.day_of_week - prev.day_of_week !== 1) continue;
      const shared = [...musclesOf(prev.exercises, library)].filter((m) => musclesOf(cur.exercises, library).has(m));
      if (shared.length > 0) {
        errors.push({
          code: 'REST_DAYS',
          message: `Week ${week}: days ${prev.day_of_week} and ${cur.day_of_week} both train ${shared.join(', ')}.`,
        });
      }
    }
  }

  // Duration feasibility.
  const limit = profile.session_length_min + DURATION_BUFFER_MIN;
  for (const session of plan.sessions) {
    const minutes = estimateSessionMinutes(session.exercises);
    if (minutes > limit) {
      errors.push({
        code: 'DURATION',
        message: `Week ${session.week_number} '${session.name_en}' is ~${minutes} min; limit is ${limit} min.`,
      });
    }
  }

  // Volume per muscle — AI plans only (templates are pre-validated content).
  if (source === 'ai') {
    const bounds = VOLUME_BOUNDS[profile.level];
    for (const [week, sessions] of byWeek(plan)) {
      const sets = new Map<string, number>();
      for (const s of sessions) {
        for (const pe of s.exercises) {
          for (const m of library.get(pe.exercise_slug)?.muscle_primary ?? []) {
            sets.set(m, (sets.get(m) ?? 0) + pe.sets);
          }
        }
      }
      for (const [muscle, count] of sets) {
        if (count > bounds.max) {
          errors.push({ code: 'VOLUME', message: `Week ${week}: ${muscle} has ${count} sets; maximum is ${bounds.max}.` });
        } else if (count < bounds.min && MAJOR_MUSCLES.has(muscle) && profile.days_per_week >= 3) {
          errors.push({ code: 'VOLUME', message: `Week ${week}: ${muscle} has ${count} sets; minimum is ${bounds.min}.` });
        }
      }
    }
  }

  return { valid: errors.length === 0, errors };
}

function byWeek(plan: DraftPlan): Map<number, DraftPlan['sessions']> {
  const weeks = new Map<number, DraftPlan['sessions']>();
  for (const s of plan.sessions) {
    weeks.set(s.week_number, [...(weeks.get(s.week_number) ?? []), s]);
  }
  return weeks;
}

function musclesOf(exercises: DraftPlan['sessions'][number]['exercises'], library: Library): Set<string> {
  return new Set(exercises.flatMap((pe) => library.get(pe.exercise_slug)?.muscle_primary ?? []));
}

/** Loads the library rows the plan logic needs (service-role client). */
export async function loadLibrary(
  // deno-lint-ignore no-explicit-any -- supabase-js client type differs between esm.sh builds
  db: any,
): Promise<Library> {
  const { data, error } = await db
    .from('exercises')
    .select('slug, equipment, muscle_primary, video_front_url, contraindications');
  if (error) throw new Error(`Failed to load exercise library: ${error.message}`);
  return libraryFrom((data ?? []) as LibraryExercise[]);
}
