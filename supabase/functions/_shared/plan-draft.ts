// In-memory plan shape shared by the validator, substitution, template builder and generate-plan flow.
// Same structure as the generate-plan plan body and plan_templates.body (contracts/ai-services.md §1).
import type { LimitationTag, PlanSource, TrainingLevel } from './types.ts';

export interface DraftExercise {
  exercise_slug: string;
  sets: number;
  reps_min: number;
  reps_max: number;
  rest_sec: number;
  rpe_target?: number | null;
  suggested_weight_kg?: number | null;
  notes_en?: string | null;
  notes_fr?: string | null;
}

export interface DraftSession {
  week_number: number;
  /** 1 = Monday … 7 = Sunday */
  day_of_week: number;
  name_en: string;
  name_fr: string;
  exercises: DraftExercise[];
}

export interface DraftPlan {
  name_en: string;
  name_fr: string;
  weeks_total: number;
  sessions: DraftSession[];
}

/** The subset of an exercises row the plan logic needs. */
export interface LibraryExercise {
  slug: string;
  equipment: string[];
  muscle_primary: string[];
  video_front_url: string | null;
  contraindications: LimitationTag[];
}

export type Library = Map<string, LibraryExercise>;

export interface PlanProfile {
  level: TrainingLevel;
  equipment: string[];
  limitations: LimitationTag[];
  session_length_min: number;
  days_per_week: number;
}

export interface ValidationError {
  code:
    | 'UNKNOWN_EXERCISE'
    | 'VIDEO_GATE'
    | 'EQUIPMENT'
    | 'CONTRAINDICATED'
    | 'REST_DAYS'
    | 'DURATION'
    | 'WEEKS'
    | 'VOLUME';
  message: string;
  exercise_slug?: string;
}

export interface ValidationResult {
  valid: boolean;
  errors: ValidationError[];
}

export type { PlanSource };

/** Seconds of work assumed per set, on top of the prescribed rest. */
export const WORK_SEC_PER_SET = 45;

/** Estimated session length in whole minutes (work + rest for every set). */
export function estimateSessionMinutes(exercises: DraftExercise[]): number {
  const seconds = exercises.reduce((sum, e) => sum + e.sets * (WORK_SEC_PER_SET + e.rest_sec), 0);
  return Math.ceil(seconds / 60);
}

export function libraryFrom(rows: LibraryExercise[]): Library {
  return new Map(rows.map((r) => [r.slug, r]));
}
