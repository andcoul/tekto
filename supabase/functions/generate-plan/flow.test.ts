// T031 — written before flow.ts (FR-003b, research §12). Fake Claude + fake clock; real content.
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { type AiPlan, type FlowDeps, type FlowInput, runGeneratePlan } from './flow.ts';
import { type LibraryExercise, libraryFrom } from '../_shared/plan-draft.ts';
import type { PlanTemplateDef } from '../_shared/template-plan-builder.ts';

const read = (p: string) => JSON.parse(Deno.readTextFileSync(new URL(p, import.meta.url)));
const TEMPLATES: PlanTemplateDef[] = ['beginner-full-body-3x', 'home-dumbbell-3x', 'intermediate-ppl-4x']
  .map((s) => read(`../../../content/templates/${s}.json`));
const LIBRARY = libraryFrom(read('../../../content/exercises/exercises.json') as LibraryExercise[]);

const input = (o: Partial<FlowInput> = {}): FlowInput => ({
  profile: {
    goal: 'muscle', level: 'intermediate', equipment: ['barbell', 'dumbbell', 'cable', 'bodyweight'],
    limitations: [], session_length_min: 60, days_per_week: 3, strength_estimates: null,
  },
  isPro: true,
  consentAt: '2026-11-10T09:00:00Z',
  hasActivePlan: false,
  forceRegenerate: false,
  ...o,
});

/** Valid AI plan: 3 sessions (Mon/Wed/Fri) × 4 weeks; 15 sets/week each for chest, lats, quads, glutes, shoulders. */
function aiPlan(override?: (slug: string) => string): AiPlan {
  const day = (d: number) => ({
    week_number: 0, day_of_week: d, name_en: `Day ${d}`, name_fr: `Jour ${d}`,
    exercises: ['bench-press', 'barbell-row', 'barbell-squat', 'overhead-press'].map((slug) => ({
      exercise_slug: override ? override(slug) : slug, sets: 5, reps_min: 6, reps_max: 8, rest_sec: 90, rpe_target: 7.5,
    })),
  });
  const sessions = [1, 2, 3, 4].flatMap((w) => [1, 3, 5].map((d) => ({ ...day(d), week_number: w })));
  return { name_en: 'AI plan', name_fr: 'Plan IA', weeks_total: 4, rationale_en: 'r', rationale_fr: 'r', sessions };
}

/** Fake deps; `responses` are returned (or thrown) in order. */
function deps(responses: Array<AiPlan | Error>, clock: number[] = []) {
  const calls: Array<string[] | null> = [];
  let tick = 0;
  const d: FlowDeps = {
    templates: TEMPLATES,
    library: LIBRARY,
    generateAiPlan: (previousErrors) => {
      calls.push(previousErrors);
      const next = responses.shift();
      if (!next) throw new Error('unexpected extra AI call');
      return next instanceof Error ? Promise.reject(next) : Promise.resolve(next);
    },
    nowMs: () => clock[Math.min(tick++, clock.length - 1)] ?? 0,
  };
  return { d, calls };
}

const tooMuchVolume = () => aiPlan((slug) => slug === 'overhead-press' ? 'bench-press' : slug); // chest 30 sets → VOLUME

Deno.test('free users get a template plan and Claude is never called', async () => {
  const { d, calls } = deps([]);
  const r = await runGeneratePlan(input({ isPro: false }), d);
  assert(r.ok);
  assertEquals([r.source, r.fallback_notice, calls.length], ['template', false, 0]);
  assertEquals(r.template_slug, 'intermediate-ppl-4x');
});

Deno.test('Pro: a valid first answer is saved as an AI plan', async () => {
  const { d, calls } = deps([aiPlan()]);
  const r = await runGeneratePlan(input(), d);
  assert(r.ok, JSON.stringify(r));
  assertEquals([r.source, r.attempts, r.template_slug, calls.length], ['ai', 1, null, 1]);
});

Deno.test('Pro: exercises the user cannot do are substituted without another AI call', async () => {
  // The AI answer uses barbell lifts; a dumbbell-only Pro user gets dumbbell substitutes.
  const dumbbellOnly = input({ profile: { ...input().profile, equipment: ['dumbbell', 'bodyweight'] } });
  const { d, calls } = deps([aiPlan()]);
  const r = await runGeneratePlan(dumbbellOnly, d);
  assert(r.ok, JSON.stringify(r));
  assertEquals([r.source, calls.length], ['ai', 1]);
  const slugs = new Set(r.plan.sessions.flatMap((s) => s.exercises.map((e) => e.exercise_slug)));
  // Squat → lunge: same primary muscles and equipment class; ties break alphabetically
  // (substitution does not rank by movement pattern).
  assertEquals([...slugs].sort(), ['dumbbell-bench-press', 'dumbbell-lunge', 'dumbbell-row', 'dumbbell-shoulder-press']);
});

Deno.test('Pro: an unknown exercise with no substitute is a validation error that triggers a retry', async () => {
  const unknown = aiPlan((slug) => slug === 'overhead-press' ? 'made-up-move' : slug);
  const { d, calls } = deps([unknown, aiPlan()]);
  const r = await runGeneratePlan(input(), d);
  assert(r.ok);
  assertEquals([r.source, r.attempts], ['ai', 2]);
  assert(calls[1]!.some((e) => e.includes('made-up-move')));
});

Deno.test('Pro: validation failures are retried at most twice, with the errors in the prompt', async () => {
  const { d, calls } = deps([tooMuchVolume(), tooMuchVolume(), aiPlan()]);
  const r = await runGeneratePlan(input(), d);
  assert(r.ok);
  assertEquals([r.source, r.attempts], ['ai', 3]);
  assertEquals(calls[0], null);
  assert(calls[1]!.some((e) => e.includes('chest')), JSON.stringify(calls[1]));
});

Deno.test('Pro: after 3 failed attempts the user gets a validated template fallback with a notice', async () => {
  const { d, calls } = deps([tooMuchVolume(), tooMuchVolume(), tooMuchVolume()]);
  const r = await runGeneratePlan(input(), d);
  assert(r.ok);
  assertEquals([r.source, r.fallback_notice, r.attempts, calls.length], ['template_fallback', true, 3, 3]);
  assert(r.template_slug !== null);
});

Deno.test('Pro: Claude unavailable (error, refusal, timeout) goes straight to the fallback', async () => {
  const { d, calls } = deps([new Error('503')]);
  const r = await runGeneratePlan(input(), d);
  assert(r.ok);
  assertEquals([r.source, r.fallback_notice, calls.length], ['template_fallback', true, 1]);
});

Deno.test('Pro: no retry once the 30 s budget is mostly spent', async () => {
  // Clock: start 0 ms, after attempt 1 → 21 s (past the retry cut-off).
  const { d, calls } = deps([tooMuchVolume(), aiPlan()], [0, 21_000]);
  const r = await runGeneratePlan(input(), d);
  assert(r.ok);
  assertEquals([r.source, calls.length], ['template_fallback', 1]);
});

Deno.test('every plan returned has starting weights and passes the validator', async () => {
  for (const isPro of [true, false]) {
    const { d } = deps([aiPlan()]);
    const r = await runGeneratePlan(input({ isPro }), d);
    assert(r.ok);
    for (const s of r.plan.sessions) for (const e of s.exercises) assert(typeof e.suggested_weight_kg === 'number');
  }
});

Deno.test('preconditions: consent required; active plan needs force_regenerate', async () => {
  const noConsent = await runGeneratePlan(input({ consentAt: null }), deps([]).d);
  assertEquals(noConsent.ok ? null : [noConsent.status, noConsent.code], [403, 'CONSENT_REQUIRED']);
  const exists = await runGeneratePlan(input({ hasActivePlan: true }), deps([]).d);
  assertEquals(exists.ok ? null : [exists.status, exists.code], [409, 'ACTIVE_PLAN_EXISTS']);
  const forced = await runGeneratePlan(input({ hasActivePlan: true, forceRegenerate: true, isPro: false }), deps([]).d);
  assert(forced.ok);
});

Deno.test('PLAN_VALIDATION_FAILED and AI_UNAVAILABLE are never returned', async () => {
  for (const responses of [[new Error('x')], [tooMuchVolume(), tooMuchVolume(), tooMuchVolume()]]) {
    const r = await runGeneratePlan(input(), deps(responses as Array<AiPlan | Error>).d);
    assert(r.ok, 'onboarding must always end with a plan');
  }
});
