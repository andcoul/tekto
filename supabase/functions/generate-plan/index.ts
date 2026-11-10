// POST /generate-plan (contracts/backend-api.md §1). Decision logic lives in flow.ts (tested);
// this file loads inputs, calls Claude, and persists the result.
import { z } from 'npm:zod@4.6.7';
import { errorResponse, jsonResponse, requireAuth } from '../_shared/auth.ts';
import { CACHE_CONTROL, callStructured, PLAN_MODEL } from '../_shared/claude.ts';
import { getDb } from '../_shared/db.ts';
import { isPro } from '../_shared/entitlement.ts';
import { isAllowed } from '../_shared/exercise-substitution.ts';
import type { DraftPlan, Library } from '../_shared/plan-draft.ts';
import { loadLibrary } from '../_shared/plan-validator.ts';
import type { BuilderProfile, PlanTemplateDef } from '../_shared/template-plan-builder.ts';
import { planStartDate } from '../_shared/week-boundary.ts';
import { type AiPlan, runGeneratePlan } from './flow.ts';

/** Per-attempt limit; with RETRY_CUTOFF_MS the whole call stays near the 30 s target (SC-002). */
const ATTEMPT_TIMEOUT_MS = 25_000;

const AiPlanSchema = z.object({
  name_en: z.string(),
  name_fr: z.string(),
  weeks_total: z.number().int(),
  rationale_en: z.string(),
  rationale_fr: z.string(),
  sessions: z.array(z.object({
    week_number: z.number().int(),
    day_of_week: z.number().int(),
    name_en: z.string(),
    name_fr: z.string(),
    exercises: z.array(z.object({
      exercise_slug: z.string(),
      sets: z.number().int(),
      reps_min: z.number().int(),
      reps_max: z.number().int(),
      rest_sec: z.number().int(),
      rpe_target: z.number().nullable(),
    })),
  })),
});

// Stable system prompt (cache prefix): rules only, no per-user or per-request data.
const SYSTEM_PROMPT = `You are Tekto's training plan generator. You create science-based, periodized strength training programs.

RULES (non-negotiable):
1. Use only exercise slugs from the AVAILABLE EXERCISES list in the user message.
2. Weekly working sets per primary muscle: beginner 10–14, intermediate 14–18, advanced 16–22.
3. Never schedule two consecutive days that train the same primary muscle.
4. Each session must fit the user's session length (count ~45 s of work per set plus the prescribed rest).
5. weeks_total is between 4 and 12; output every session of every week (week_number 1..weeks_total, day_of_week 1 = Monday … 7 = Sunday).
6. Show progressive overload across weeks (reps, sets or intensity).
7. Set rpe_target only for intermediate and advanced users; otherwise null.
8. Write names and rationales in both English and French.`;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  let userId: string;
  try {
    userId = await requireAuth(req);
  } catch (e) {
    return errorResponse((e as Error).message, 401, 'UNAUTHORIZED');
  }
  const body = await req.json().catch(() => ({})) as { force_regenerate?: boolean };
  const db = getDb();

  const { data: user } = await db.from('users').select('*').eq('id', userId).maybeSingle();
  if (!user) return errorResponse('User profile missing required fields.', 400, 'PROFILE_INCOMPLETE');

  const [{ data: sub }, { data: active }, { data: templateRows }, library] = await Promise.all([
    db.from('subscriptions').select('tier, is_trial, trial_ends_at, current_period_ends_at').eq('user_id', userId).maybeSingle(),
    db.from('plans').select('id').eq('user_id', userId).eq('status', 'active').maybeSingle(),
    db.from('plan_templates').select('body'),
    loadLibrary(db),
  ]);

  const profile: BuilderProfile = {
    goal: user.goal,
    level: user.level,
    equipment: user.equipment ?? [],
    limitations: user.limitations ?? [],
    session_length_min: user.session_length_min,
    days_per_week: user.days_per_week,
    strength_estimates: user.strength_estimates,
  };

  const result = await runGeneratePlan(
    {
      profile,
      isPro: isPro(sub),
      consentAt: user.consent_at,
      hasActivePlan: active !== null,
      forceRegenerate: body.force_regenerate === true,
    },
    {
      templates: (templateRows ?? []).map((r: { body: PlanTemplateDef }) => r.body),
      library,
      nowMs: () => Date.now(),
      generateAiPlan: (previousErrors) => generateAiPlan(profile, user.language, library, previousErrors),
    },
  );
  if (!result.ok) return errorResponse(result.message, result.status, result.code);

  if (active && body.force_regenerate) {
    await db.from('plans').update({ status: 'archived' }).eq('id', active.id);
  }

  const startDate = planStartDate(new Date(), user.timezone ?? 'UTC');
  const { data: plan, error: planError } = await db.from('plans').insert({
    user_id: userId,
    name: result.plan.name_en,
    weeks_total: result.plan.weeks_total,
    rationale_en: result.rationale_en,
    rationale_fr: result.rationale_fr,
    source: result.source,
    template_slug: result.template_slug,
    start_date: startDate,
    generated_by: result.source === 'ai' ? 'ai' : `template:${result.template_slug}`,
  }).select('id').single();
  if (planError || !plan) return errorResponse(`Failed to save plan: ${planError?.message}`, 500, 'SAVE_FAILED');

  try {
    const sessions = await saveSessions(db, plan.id, result.plan, library);
    if (!user.onboarding_completed_at) {
      await db.from('users').update({ onboarding_completed_at: new Date().toISOString() }).eq('id', userId);
    }
    console.log(JSON.stringify({ event: 'plan_generated', source: result.source, attempts: result.attempts }));
    return jsonResponse({
      plan: {
        id: plan.id,
        name_en: result.plan.name_en,
        name_fr: result.plan.name_fr,
        weeks_total: result.plan.weeks_total,
        current_week: 1,
        start_date: startDate,
        source: result.source,
        template_slug: result.template_slug,
        fallback_notice: result.fallback_notice,
        notices: result.notices,
        sessions,
      },
    }, 201);
  } catch (err) {
    await db.from('plans').delete().eq('id', plan.id); // cascades to sessions + plan_exercises
    return errorResponse(`Failed to save plan: ${(err as Error).message}`, 500, 'SAVE_FAILED');
  }
});

async function generateAiPlan(
  profile: BuilderProfile,
  language: string,
  library: Library,
  previousErrors: string[] | null,
): Promise<AiPlan> {
  const available = [...library.values()]
    .filter((e) => e.video_front_url && isAllowed(e, profile))
    .map((e) => ({ slug: e.slug, equipment: e.equipment, muscle_primary: e.muscle_primary }));

  const userMessage = [
    'USER PROFILE:',
    `- Goal: ${profile.goal}`,
    `- Level: ${profile.level}`,
    `- Days per week: ${profile.days_per_week}`,
    `- Session length: ${profile.session_length_min} minutes`,
    `- Equipment: ${profile.equipment.join(', ')}`,
    `- Limitations: ${profile.limitations.length ? profile.limitations.join(', ') : 'none'}`,
    `- Language preference: ${language}`,
    '',
    'AVAILABLE EXERCISES (only these, already filtered for equipment, video and limitations):',
    JSON.stringify(available),
  ].join('\n');

  const messages: Array<{ role: 'user'; content: string }> = [{ role: 'user', content: userMessage }];
  if (previousErrors) {
    messages[0].content += `\n\nYour previous response had these issues: ${previousErrors.join(' | ')}\n` +
      'Please regenerate the plan correcting these issues. All other rules still apply.';
  }

  const { output } = await callStructured({
    fn: 'generate-plan',
    model: PLAN_MODEL,
    system: [{ type: 'text', text: SYSTEM_PROMPT, cache_control: CACHE_CONTROL }],
    messages,
    schema: AiPlanSchema,
    effort: 'high',
    maxTokens: 64_000,
    timeoutMs: ATTEMPT_TIMEOUT_MS,
    refusalFallback: true,
  });
  return output;
}

/** Inserts sessions and plan_exercises; returns the contract's nested session list. */
async function saveSessions(
  // deno-lint-ignore no-explicit-any -- supabase-js client from esm.sh
  db: any,
  planId: string,
  plan: DraftPlan,
  library: Library,
) {
  const sessionRows = plan.sessions.map((s) => ({
    plan_id: planId,
    week_number: s.week_number,
    day_of_week: s.day_of_week,
    name_en: s.name_en,
    name_fr: s.name_fr,
    muscle_groups: [...new Set(s.exercises.flatMap((e) => library.get(e.exercise_slug)?.muscle_primary ?? []))],
    estimated_min: Math.ceil(s.exercises.reduce((sum, e) => sum + e.sets * (45 + e.rest_sec), 0) / 60),
  }));
  const { data: savedSessions, error: sErr } = await db.from('sessions').insert(sessionRows).select('id');
  if (sErr) throw new Error(sErr.message);

  const exerciseRows = plan.sessions.flatMap((s, i) =>
    s.exercises.map((e, order) => ({
      session_id: savedSessions[i].id,
      exercise_slug: e.exercise_slug,
      sort_order: order,
      sets: e.sets,
      reps_min: e.reps_min,
      reps_max: e.reps_max,
      rpe_target: e.rpe_target ?? null,
      rest_sec: e.rest_sec,
      suggested_weight_kg: e.suggested_weight_kg ?? null,
    }))
  );
  const { data: savedExercises, error: eErr } = await db.from('plan_exercises').insert(exerciseRows).select('id, session_id');
  if (eErr) throw new Error(eErr.message);

  return plan.sessions.map((s, i) => ({
    id: savedSessions[i].id,
    week_number: s.week_number,
    day_number: s.day_of_week,
    name_en: s.name_en,
    name_fr: s.name_fr,
    target_muscles: sessionRows[i].muscle_groups,
    estimated_duration_min: sessionRows[i].estimated_min,
    exercises: s.exercises.map((e, order) => {
      const ex = library.get(e.exercise_slug);
      const saved = (savedExercises as Array<{ id: string; session_id: string }>)
        .filter((x) => x.session_id === savedSessions[i].id)[order];
      return {
        plan_exercise_id: saved?.id,
        exercise: { slug: e.exercise_slug, muscle_primary: ex?.muscle_primary ?? [] },
        sets: e.sets,
        reps_min: e.reps_min,
        reps_max: e.reps_max,
        rest_sec: e.rest_sec,
        rpe_target: e.rpe_target ?? null,
        suggested_weight_kg: e.suggested_weight_kg ?? null,
      };
    }),
  }));
}
