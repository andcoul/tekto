// T087 — user-initiated exercise swap (FR-028, Constitution IV). Rule-based and available to
// every tier: no Pro check and no AI call. Pure: data access is injected so it is unit-tested.
import { isAllowed } from '../_shared/exercise-substitution.ts';
import type { LimitationTag } from '../_shared/types.ts';

export interface SwapExercise {
  id: string;
  slug: string;
  name_en: string;
  name_fr: string;
  video_front_url: string | null;
  equipment: string[];
  muscle_primary: string[];
  contraindications: LimitationTag[];
}

export interface SwapPlanExercise {
  id: string;
  exercise_id: string;
  user_id: string;
  plan_status: string;
}

export interface SwapProfile {
  equipment: string[];
  limitations: LimitationTag[];
  /** Loaded for logging only; it never changes the outcome (FR-028). */
  tier: 'free' | 'pro';
}

export interface SwapDeps {
  loadExercise(id: string): Promise<SwapExercise | null>;
  loadExerciseBySlug(slug: string): Promise<SwapExercise | null>;
  loadPlanExercise(id: string): Promise<SwapPlanExercise | null>;
  loadProfile(userId: string): Promise<SwapProfile>;
  applySwap(planExerciseId: string, newExerciseId: string): Promise<void>;
}

export interface SwapRequest {
  plan_exercise_id?: string;
  /** Either the target's id or its slug (the app caches exercises by slug). */
  new_exercise_id?: string;
  new_exercise_slug?: string;
}

export interface SwapResult {
  status: number;
  // deno-lint-ignore no-explicit-any -- JSON body: either the contract response or { error, code }
  body: any;
}

const fail = (status: number, code: string, error: string): SwapResult => ({ status, body: { error, code } });

export async function handleSwap(userId: string, req: SwapRequest, deps: SwapDeps): Promise<SwapResult> {
  if (!req.plan_exercise_id || !(req.new_exercise_id || req.new_exercise_slug)) {
    return fail(400, 'INVALID_REQUEST', 'plan_exercise_id and new_exercise_id or new_exercise_slug are required');
  }

  const target = req.new_exercise_id
    ? await deps.loadExercise(req.new_exercise_id)
    : await deps.loadExerciseBySlug(req.new_exercise_slug!);
  if (!target) return fail(404, 'EXERCISE_NOT_FOUND', 'Exercise not found');

  const planExercise = await deps.loadPlanExercise(req.plan_exercise_id);
  if (!planExercise) return fail(404, 'PLAN_EXERCISE_NOT_FOUND', 'Plan exercise not found');
  if (planExercise.user_id !== userId) return fail(403, 'FORBIDDEN', 'Not your plan');
  if (planExercise.plan_status !== 'active') return fail(400, 'PLAN_NOT_ACTIVE', 'Plan is not active');

  // Video Gate first: a video-less target is never applied (Constitution IV).
  if (!target.video_front_url) return fail(400, 'EXERCISE_NO_VIDEO', `'${target.slug}' has no video`);

  const profile = await deps.loadProfile(userId);
  // Only equipment and limitations matter for isAllowed; the other PlanProfile fields are unused.
  if (!isAllowed(target, { equipment: profile.equipment, limitations: profile.limitations, level: 'beginner', session_length_min: 0, days_per_week: 0 })) {
    return fail(400, 'EXERCISE_NOT_ALLOWED', `'${target.slug}' needs unavailable equipment or is contraindicated`);
  }

  const current = await deps.loadExercise(planExercise.exercise_id);
  const shared = current?.muscle_primary.some((m) => target.muscle_primary.includes(m)) ?? false;
  if (!shared) return fail(400, 'EXERCISE_NOT_EQUIVALENT', `'${target.slug}' does not train the same primary muscle`);

  await deps.applySwap(planExercise.id, target.id);
  return {
    status: 200,
    body: {
      plan_exercise_id: planExercise.id,
      new_exercise: { id: target.id, slug: target.slug, name_en: target.name_en, name_fr: target.name_fr },
    },
  };
}
