// generate-plan decision flow (T037; FR-002, FR-002a, FR-003b; research §11–§12).
// Pure apart from the injected AI call and clock, so every branch is unit-tested.
import { findSubstitute, isAllowed } from '../_shared/exercise-substitution.ts';
import type { DraftPlan, Library } from '../_shared/plan-draft.ts';
import { validatePlan } from '../_shared/plan-validator.ts';
import { startingWeightKg } from '../_shared/starting-weights.ts';
import { type BuilderProfile, buildTemplatePlan, type PlanTemplateDef } from '../_shared/template-plan-builder.ts';
import type { PlanSource } from '../_shared/types.ts';

export type AiPlan = DraftPlan & { rationale_en: string; rationale_fr: string };

export interface FlowInput {
  profile: BuilderProfile;
  isPro: boolean;
  consentAt: string | null;
  hasActivePlan: boolean;
  forceRegenerate: boolean;
}

export interface FlowDeps {
  templates: PlanTemplateDef[];
  library: Library;
  /** One Claude attempt. `previousErrors` is null on the first attempt. Throws when unavailable. */
  generateAiPlan: (previousErrors: string[] | null) => Promise<AiPlan>;
  nowMs: () => number;
}

export type FlowResult =
  | {
    ok: true;
    plan: DraftPlan;
    source: PlanSource;
    template_slug: string | null;
    rationale_en: string;
    rationale_fr: string;
    fallback_notice: boolean;
    notices: string[];
    attempts: number;
  }
  | { ok: false; status: number; code: 'CONSENT_REQUIRED' | 'ACTIVE_PLAN_EXISTS'; message: string };

/** 1 attempt + 2 retries (Constitution III). */
export const MAX_ATTEMPTS = 3;
/** No new attempt after this much of the 30 s budget (SC-002) is spent; the fallback is instant. */
export const RETRY_CUTOFF_MS = 20_000;

export async function runGeneratePlan(input: FlowInput, deps: FlowDeps): Promise<FlowResult> {
  if (!input.consentAt) {
    return { ok: false, status: 403, code: 'CONSENT_REQUIRED', message: 'Health-data consent is required before a plan is generated.' };
  }
  if (input.hasActivePlan && !input.forceRegenerate) {
    return { ok: false, status: 409, code: 'ACTIVE_PLAN_EXISTS', message: 'An active plan exists; pass force_regenerate to replace it.' };
  }

  if (!input.isPro) return templateResult(input, deps, 'template', 0);

  const started = deps.nowMs();
  let previousErrors: string[] | null = null;
  let attempts = 0;
  while (attempts < MAX_ATTEMPTS) {
    if (attempts > 0 && deps.nowMs() - started > RETRY_CUTOFF_MS) break;
    attempts++;
    let ai: AiPlan;
    try {
      ai = await deps.generateAiPlan(previousErrors);
    } catch (err) {
      console.log(JSON.stringify({ event: 'plan_ai_unavailable', attempts, error: String(err) }));
      break;
    }

    const plan = withStartingWeights(substituteDisallowed(ai, input.profile, deps.library), input.profile, deps.library);
    const result = validatePlan(plan, input.profile, deps.library, 'ai');
    if (result.valid) {
      return {
        ok: true, plan, source: 'ai', template_slug: null,
        rationale_en: ai.rationale_en, rationale_fr: ai.rationale_fr,
        fallback_notice: false, notices: [], attempts,
      };
    }
    previousErrors = result.errors.map((e) => e.message);
    console.log(JSON.stringify({ event: 'plan_validation_failed', attempts, errors: previousErrors }));
  }

  return templateResult(input, deps, 'template_fallback', attempts);
}

function templateResult(input: FlowInput, deps: FlowDeps, source: PlanSource, attempts: number): FlowResult {
  const t = buildTemplatePlan(deps.templates, input.profile, deps.library);
  return {
    ok: true,
    plan: t.plan,
    source,
    template_slug: t.template_slug,
    rationale_en: t.rationale_en,
    rationale_fr: t.rationale_fr,
    fallback_notice: source === 'template_fallback',
    notices: t.notices,
    attempts,
  };
}

/**
 * Replaces exercises that are unknown-but-substitutable, have no video, need unavailable equipment
 * or are contraindicated (FR-003b step 1) — no AI call. Anything without a substitute is left for
 * the validator to report.
 */
function substituteDisallowed(plan: AiPlan, profile: BuilderProfile, library: Library): DraftPlan {
  return {
    name_en: plan.name_en,
    name_fr: plan.name_fr,
    weeks_total: plan.weeks_total,
    sessions: plan.sessions.map((s) => {
      const used = new Set<string>();
      const exercises = s.exercises.map((e) => {
        const ex = library.get(e.exercise_slug);
        const ok = ex && ex.video_front_url && isAllowed(ex, profile);
        if (ok) {
          used.add(e.exercise_slug);
          return { ...e };
        }
        const sub = findSubstitute(e.exercise_slug, profile, library, { exclude: used });
        if (!sub) return { ...e };
        used.add(sub.slug);
        return { ...e, exercise_slug: sub.slug };
      });
      return { ...s, exercises };
    }),
  };
}

/** Fills `suggested_weight_kg` where the AI left it empty (US1 scenario 3). */
function withStartingWeights(plan: DraftPlan, profile: BuilderProfile, library: Library): DraftPlan {
  return {
    ...plan,
    sessions: plan.sessions.map((s) => ({
      ...s,
      exercises: s.exercises.map((e) => {
        const ex = library.get(e.exercise_slug);
        if (!ex || typeof e.suggested_weight_kg === 'number') return e;
        return { ...e, suggested_weight_kg: startingWeightKg(ex, e, profile.level, profile.strength_estimates) };
      }),
    })),
  };
}
