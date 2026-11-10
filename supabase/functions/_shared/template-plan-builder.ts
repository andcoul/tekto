// Free-tier rule-based plans (T036; FR-002, research §11). No AI call. Also the Pro fallback (FR-003b).
import { findSubstitute, isAllowed } from './exercise-substitution.ts';
import {
  type DraftExercise,
  type DraftPlan,
  type DraftSession,
  estimateSessionMinutes,
  type Library,
  type PlanProfile,
} from './plan-draft.ts';
import { startingWeightKg } from './starting-weights.ts';
import type { StrengthEstimates, TrainingGoal, TrainingLevel } from './types.ts';

export interface TemplateSessionDef {
  ref: string;
  day_of_week: number;
  name_en: string;
  name_fr: string;
  exercises: DraftExercise[];
}

/** Shape of content/templates/*.json and plan_templates.body. */
export interface PlanTemplateDef {
  slug: string;
  level: TrainingLevel;
  days_per_week: number;
  equipment_required: string[];
  name_en: string;
  name_fr: string;
  weeks_total: number;
  rationale_en: string;
  rationale_fr: string;
  sessions: TemplateSessionDef[];
}

export interface BuilderProfile extends PlanProfile {
  goal: TrainingGoal;
  strength_estimates?: StrengthEstimates | null;
}

export interface TemplatePlanResult {
  plan: DraftPlan;
  template_slug: string;
  rationale_en: string;
  rationale_fr: string;
  /** Localization keys for non-blocking cards (contracts/backend-api.md §1). */
  notices: string[];
}

export const MAX_FREE_SESSIONS = 4;
const MIN_EXERCISES = 3;
const MIN_SETS = 2;
const MIN_REST_SEC = 60;
const FULL_BODY = 'beginner-full-body-3x';
const DUMBBELL = 'home-dumbbell-3x';
const SPLIT = 'intermediate-ppl-4x';

/** Equipment first, then level, then goal. */
export function selectTemplateSlug(p: BuilderProfile): string {
  if (!p.equipment.includes('barbell')) return DUMBBELL;
  if (p.level === 'beginner') return FULL_BODY;
  return p.goal === 'muscle' || p.goal === 'strength' ? SPLIT : FULL_BODY;
}

export function buildTemplatePlan(
  templates: PlanTemplateDef[],
  profile: BuilderProfile,
  library: Library,
): TemplatePlanResult {
  const bySlug = new Map(templates.map((t) => [t.slug, t]));
  let template = mustGet(bySlug, selectTemplateSlug(profile));
  // A 4-day split is a poor fit for 1–2 days a week: use full body instead.
  if (profile.days_per_week <= 2 && template.sessions.length > 3) template = mustGet(bySlug, FULL_BODY);

  const notices: string[] = [];
  if (profile.days_per_week > MAX_FREE_SESSIONS) notices.push('free_plan_days_capped');

  const pattern = scheduleWeek(template, Math.min(profile.days_per_week, MAX_FREE_SESSIONS))
    .map((s) => ({ ...s, exercises: fitSession(adaptExercises(s.exercises, profile, library), profile.session_length_min) }))
    .map((s) => ({
      ...s,
      exercises: s.exercises.map((e) => ({
        ...e,
        suggested_weight_kg: startingWeightKg(library.get(e.exercise_slug)!, e, profile.level, profile.strength_estimates),
      })),
    }));

  const sessions: DraftSession[] = [];
  for (let week = 1; week <= template.weeks_total; week++) {
    for (const s of pattern) {
      sessions.push({
        week_number: week,
        day_of_week: s.day_of_week,
        name_en: s.name_en,
        name_fr: s.name_fr,
        exercises: s.exercises.map((e) => ({ ...e })),
      });
    }
  }

  return {
    plan: { name_en: template.name_en, name_fr: template.name_fr, weeks_total: template.weeks_total, sessions },
    template_slug: template.slug,
    rationale_en: template.rationale_en,
    rationale_fr: template.rationale_fr,
    notices,
  };
}

function mustGet(map: Map<string, PlanTemplateDef>, slug: string): PlanTemplateDef {
  const t = map.get(slug);
  if (!t) throw new Error(`Template '${slug}' is not loaded`);
  return t;
}

/** Picks the sessions for `count` days and their weekdays (no two consecutive days for full body). */
function scheduleWeek(template: PlanTemplateDef, count: number): TemplateSessionDef[] {
  const s = template.sessions;
  if (count <= s.length) {
    if (count === 1) return [{ ...s[0], day_of_week: 1 }];
    if (count === 2) return [{ ...s[0], day_of_week: 1 }, { ...s[1], day_of_week: 4 }];
    return s.slice(0, count);
  }
  // More days than the template has: repeat from the start on the free days, Sunday first.
  const used = new Set(s.map((x) => x.day_of_week));
  const freeDays = [7, 6, 4, 2].filter((d) => !used.has(d));
  const extra = Array.from({ length: count - s.length }, (_, i) => ({ ...s[i % s.length], day_of_week: freeDays[i] }));
  return [...s, ...extra].sort((a, b) => a.day_of_week - b.day_of_week);
}

/** Replaces exercises the user cannot do; drops one with no valid substitute. */
function adaptExercises(exercises: DraftExercise[], profile: PlanProfile, library: Library): DraftExercise[] {
  const out: DraftExercise[] = [];
  const inSession = new Set<string>();
  for (const e of exercises) {
    const ex = library.get(e.exercise_slug);
    if (ex && ex.video_front_url && isAllowed(ex, profile) && !inSession.has(ex.slug)) {
      out.push({ ...e });
      inSession.add(ex.slug);
      continue;
    }
    const sub = findSubstitute(e.exercise_slug, profile, library, { exclude: new Set(inSession) });
    if (sub) {
      out.push({ ...e, exercise_slug: sub.slug });
      inSession.add(sub.slug);
    }
  }
  return out;
}

/** Trims accessories from the end (keeping ≥ 3), then sets, then rest, until the session fits. */
function fitSession(exercises: DraftExercise[], minutes: number): DraftExercise[] {
  const list = exercises.map((e) => ({ ...e }));
  const fits = () => estimateSessionMinutes(list) <= minutes;
  while (!fits() && list.length > MIN_EXERCISES) list.pop();
  while (!fits() && list.some((e) => e.sets > MIN_SETS)) {
    const biggest = list.reduce((a, b) => (b.sets > a.sets ? b : a));
    biggest.sets--;
  }
  while (!fits() && list.some((e) => e.rest_sec > MIN_REST_SEC)) {
    const longest = list.reduce((a, b) => (b.rest_sec > a.rest_sec ? b : a));
    longest.rest_sec = Math.max(MIN_REST_SEC, longest.rest_sec - 15);
  }
  return list;
}
