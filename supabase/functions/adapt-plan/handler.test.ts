// T081 — adapt-plan orchestration (FR-026, FR-027; research §10; contracts/backend-api.md §2).
// Written before handler.ts (T084). In-memory ports: no database, no model.
import { assert, assertEquals } from 'jsr:@std/assert@1';
import type { SetLogRow } from '../_shared/plan-adaptation.ts';
import {
  type AdaptDeps,
  type AdaptPlan,
  type Explanation,
  handleBatch,
  handleUserMode,
  type WeekExercise,
  type WeekSnapshot,
} from './handler.ts';

const USER = 'user-1';
// Plan starts Monday 2 Nov 2026 (Paris). Week 1 = 2–8 Nov, week 2 = 9–15 Nov.
const START = '2026-11-02';
const DURING_WEEK_1 = new Date('2026-11-06T10:00:00Z'); // Friday of week 1
const AFTER_WEEK_1 = new Date('2026-11-09T10:00:00Z'); // Monday of week 2
const AFTER_WEEK_2 = new Date('2026-11-16T10:00:00Z'); // Monday of week 3

function plan(over: Partial<AdaptPlan> = {}): AdaptPlan {
  return {
    id: 'plan-1', user_id: USER, start_date: START, current_week: 1, weeks_total: 4, last_adapted_week: 0,
    adaptation_log: [], timezone: 'Europe/Paris', pro: true, ...over,
  };
}

function ex(id: string, sessionId: string, over: Partial<WeekExercise> = {}): WeekExercise {
  return {
    id, session_id: sessionId, sort_order: 0, exercise_slug: 'barbell-squat', equipment: ['barbell'],
    reps_min: 5, reps_max: 8, rpe_target: 7, rir_target: null, suggested_weight_kg: 80, ...over,
  };
}

const set = (peId: string, over: Partial<SetLogRow> = {}): SetLogRow => ({
  id: `sl-${peId}-${Math.random()}`, plan_exercise_id: peId, weight_kg: 80, reps: 6, rpe_actual: 7, workout_log_id: 'wl', ...over,
});

/** Two sessions per week; squat on day 1, bench on day 3. */
function week(n: number, opts: { finished?: boolean[]; logs?: SetLogRow[]; effort?: (number | null)[] } = {}): WeekSnapshot {
  const finished = opts.finished ?? [false, false];
  return {
    sessions: [
      { id: `w${n}-s1`, day_of_week: 1, finished: finished[0], effort_rating: opts.effort?.[0] ?? null },
      { id: `w${n}-s2`, day_of_week: 3, finished: finished[1], effort_rating: opts.effort?.[1] ?? null },
    ],
    exercises: [
      ex(`w${n}-squat`, `w${n}-s1`),
      ex(`w${n}-bench`, `w${n}-s2`, { exercise_slug: 'bench-press', suggested_weight_kg: 60 }),
    ],
    setLogs: opts.logs ?? [],
  };
}

function setup(opts: { plans?: AdaptPlan[]; weeks?: Record<number, WeekSnapshot>; now?: Date; explain?: () => Promise<Explanation> } = {}) {
  const plans = new Map((opts.plans ?? [plan()]).map((p) => [p.id, { ...p, adaptation_log: [...p.adaptation_log] }]));
  const weeks = opts.weeks ?? { 1: week(1), 2: week(2), 3: week(3), 4: week(4) };
  const calls = { updates: [] as { plan_exercise_id: string; field: string; value: number }[], explain: 0, claims: [] as number[] };
  const deps: AdaptDeps = {
    now: () => opts.now ?? AFTER_WEEK_1,
    loadPlan: (id) => Promise.resolve(plans.get(id) ?? null),
    listActivePlans: () => Promise.resolve([...plans.values()]),
    loadWeek: (_planId, n) => Promise.resolve(weeks[n] ?? { sessions: [], exercises: [], setLogs: [] }),
    claimWeek: (planId, n) => {
      const p = plans.get(planId)!;
      if (p.last_adapted_week >= n) return Promise.resolve(false);
      assert(n <= p.current_week, `claimed week ${n} ahead of current_week ${p.current_week}`);
      p.last_adapted_week = n;
      calls.claims.push(n);
      return Promise.resolve(true);
    },
    setCurrentWeek: (planId, n) => {
      plans.get(planId)!.current_week = n;
      return Promise.resolve();
    },
    applyUpdates: (updates) => {
      calls.updates.push(...updates);
      return Promise.resolve();
    },
    appendLog: (planId, entry) => {
      plans.get(planId)!.adaptation_log.push(entry);
      return Promise.resolve();
    },
    explain: (input) => {
      calls.explain += 1;
      if (opts.explain) return opts.explain();
      return Promise.resolve({
        reasons: input.adaptations.map((a) => ({ plan_exercise_id: a.plan_exercise_id, reason_en: 'AI en', reason_fr: 'AI fr' })),
        summary_en: 'AI summary', summary_fr: 'Résumé IA',
      });
    },
  };
  return { deps, plans, calls };
}

const easyWeek1 = () =>
  week(1, {
    finished: [true, true],
    logs: [set('w1-squat'), set('w1-squat'), set('w1-bench', { weight_kg: 60 }), set('w1-bench', { weight_kg: 60 })],
  });

// ---- user mode ----

Deno.test('user mode: a completed week adapts the matching exercises of the next week', async () => {
  const { deps, calls, plans } = setup({ now: DURING_WEEK_1, weeks: { 1: easyWeek1(), 2: week(2) } });
  const res = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  assertEquals(res.status, 200);
  assertEquals(res.body.already_adapted, false);
  assertEquals([res.body.sessions_scheduled, res.body.sessions_completed], [2, 2]);
  assertEquals(calls.updates, [
    { plan_exercise_id: 'w2-squat', field: 'suggested_weight_kg', value: 82.5 },
    { plan_exercise_id: 'w2-bench', field: 'suggested_weight_kg', value: 62.5 },
  ]);
  assertEquals(res.body.adaptations[0], {
    plan_exercise_id: 'w2-squat', field_changed: 'suggested_weight_kg', old_value: 80, new_value: 82.5,
    reason_en: 'AI en', reason_fr: 'AI fr',
  });
  assertEquals(plans.get('plan-1')!.last_adapted_week, 1);
  assertEquals(plans.get('plan-1')!.adaptation_log.length, 1);
});

Deno.test('user mode: both suggested_weight_kg and reps_max events are applied', async () => {
  // Light squat → reps_max path; normal bench → weight path.
  const w1 = week(1, {
    finished: [true, true],
    logs: [set('w1-squat', { weight_kg: 10 }), set('w1-bench', { weight_kg: 60 })],
  });
  w1.exercises[0].suggested_weight_kg = 10;
  const { deps, calls } = setup({ now: DURING_WEEK_1, weeks: { 1: w1, 2: week(2) } });
  await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  assertEquals(calls.updates.map((u) => u.field).sort(), ['reps_max', 'suggested_weight_kg']);
  assertEquals(calls.updates.find((u) => u.field === 'reps_max'), { plan_exercise_id: 'w2-squat', field: 'reps_max', value: 9 });
});

Deno.test('user mode: a second call is idempotent and returns the stored summary', async () => {
  const { deps, calls } = setup({ now: DURING_WEEK_1, weeks: { 1: easyWeek1(), 2: week(2) } });
  const first = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  const second = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  assertEquals(second.status, 200);
  assertEquals(second.body.already_adapted, true);
  assertEquals(second.body.adaptations, first.body.adaptations);
  assertEquals(calls.updates.length, 2, 'no second application');
});

Deno.test('user mode: WEEK_NOT_ENDED while a session is unfinished and the week has not ended', async () => {
  const { deps, calls } = setup({ now: DURING_WEEK_1, weeks: { 1: week(1, { finished: [true, false] }), 2: week(2) } });
  const res = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  assertEquals([res.status, res.body.code], [400, 'WEEK_NOT_ENDED']);
  assertEquals(calls.claims, []);
});

Deno.test('user mode: once the week boundary passed, an unfinished week is reviewed (skipped = missed)', async () => {
  const w1 = week(1, { finished: [true, false], logs: [set('w1-squat'), set('w1-squat')] });
  const { deps } = setup({ now: AFTER_WEEK_1, plans: [plan({ current_week: 2 })], weeks: { 1: w1, 2: week(2) } });
  const res = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  assertEquals(res.status, 200);
  assertEquals([res.body.sessions_scheduled, res.body.sessions_completed], [2, 1]);
});

Deno.test('user mode: PRO_REQUIRED (403) on a free plan', async () => {
  const { deps } = setup({ plans: [plan({ pro: false })], now: DURING_WEEK_1, weeks: { 1: easyWeek1() } });
  const res = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  assertEquals([res.status, res.body.code], [403, 'PRO_REQUIRED']);
});

Deno.test("user mode: PLAN_NOT_FOUND (404) for an unknown plan or someone else's", async () => {
  const { deps } = setup({ plans: [plan({ user_id: 'other' })] });
  assertEquals((await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps)).body.code, 'PLAN_NOT_FOUND');
  assertEquals((await handleUserMode(USER, { plan_id: 'nope', completed_week: 1 }, deps)).body.code, 'PLAN_NOT_FOUND');
});

Deno.test('user mode: INVALID_REQUEST for a week outside the plan', async () => {
  const { deps } = setup();
  for (const completed_week of [0, 5, 1.5]) {
    assertEquals((await handleUserMode(USER, { plan_id: 'plan-1', completed_week }, deps)).body.code, 'INVALID_REQUEST');
  }
});

Deno.test('explanation model failure falls back to the deterministic reasons; adaptation still applies', async () => {
  const { deps, calls } = setup({
    now: DURING_WEEK_1,
    weeks: { 1: easyWeek1(), 2: week(2) },
    explain: () => Promise.reject(new Error('model down')),
  });
  const res = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  assertEquals(res.status, 200);
  assertEquals(calls.updates.length, 2);
  assert(res.body.adaptations[0].reason_en.includes('RPE'), res.body.adaptations[0].reason_en);
  assert(res.body.adaptations[0].reason_fr.length > 0);
  assert(res.body.summary_en.includes('2 of 2'), res.body.summary_en);
  assert(res.body.summary_fr.includes('2 sur 2'), res.body.summary_fr);
});

Deno.test('a reason the model leaves out keeps its deterministic text', async () => {
  const { deps } = setup({
    now: DURING_WEEK_1,
    weeks: { 1: easyWeek1(), 2: week(2) },
    explain: () =>
      Promise.resolve({ reasons: [{ plan_exercise_id: 'w2-squat', reason_en: 'AI en', reason_fr: 'AI fr' }], summary_en: 's', summary_fr: 's' }),
  });
  const res = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  const bench = res.body.adaptations.find((a: { plan_exercise_id: string }) => a.plan_exercise_id === 'w2-bench');
  assert(bench.reason_en !== 'AI en' && bench.reason_en.length > 0);
});

Deno.test('a week with no changes is still claimed and logged, without calling the model', async () => {
  const { deps, calls, plans } = setup({ now: DURING_WEEK_1, weeks: { 1: week(1, { finished: [true, true] }), 2: week(2) } });
  const res = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  assertEquals(res.body.adaptations, []);
  assertEquals(calls.explain, 0);
  assertEquals(plans.get('plan-1')!.last_adapted_week, 1);
});

Deno.test('the last week of a plan is claimed with no changes (there is no next week)', async () => {
  const p = plan({ weeks_total: 1 });
  const { deps, calls } = setup({ plans: [p], now: DURING_WEEK_1, weeks: { 1: easyWeek1() } });
  const res = await handleUserMode(USER, { plan_id: 'plan-1', completed_week: 1 }, deps);
  assertEquals(res.status, 200);
  assertEquals(calls.updates, []);
});

// ---- batch mode ----

Deno.test('batch: adapts only Pro plans whose week ended and is unadapted; advances current_week for all', async () => {
  const { deps, plans, calls } = setup({
    now: AFTER_WEEK_1,
    plans: [plan({ id: 'pro' }), plan({ id: 'free', pro: false }), plan({ id: 'done', last_adapted_week: 1 })],
    weeks: { 1: easyWeek1(), 2: week(2) },
  });
  const res = await handleBatch(deps);
  assertEquals(res.body, { processed: 3, adapted: 1, advanced_only: 1 });
  assertEquals(plans.get('pro')!.last_adapted_week, 1);
  assertEquals(plans.get('free')!.current_week, 2);
  assertEquals(plans.get('free')!.last_adapted_week, 1, 'claimed so a later upgrade does not re-adapt old weeks');
  assertEquals(plans.get('done')!.current_week, 2);
  assert(calls.updates.every((u) => u.plan_exercise_id.startsWith('w2-')));
  assertEquals(calls.updates.length, 2, 'free plan exercises unchanged; the done plan not re-adapted');
});

Deno.test('batch: skipped sessions are inputs — 1 of 2 sessions logged still produces a review', async () => {
  const w1 = week(1, { finished: [true, false], logs: [set('w1-squat'), set('w1-squat')] });
  const { deps, plans } = setup({ now: AFTER_WEEK_1, weeks: { 1: w1, 2: week(2) } });
  await handleBatch(deps);
  const entry = plans.get('plan-1')!.adaptation_log[0];
  assertEquals([entry.sessions_scheduled, entry.sessions_completed], [2, 1]);
});

Deno.test('batch: a second run adapts nothing (already adapted)', async () => {
  const { deps, calls } = setup({ now: AFTER_WEEK_1, weeks: { 1: easyWeek1(), 2: week(2) } });
  await handleBatch(deps);
  const again = await handleBatch(deps);
  assertEquals(again.body, { processed: 1, adapted: 0, advanced_only: 0 });
  assertEquals(calls.claims, [1]);
});

Deno.test('batch: nothing happens before the week ends', async () => {
  const { deps, calls, plans } = setup({ now: DURING_WEEK_1, weeks: { 1: easyWeek1() } });
  assertEquals((await handleBatch(deps)).body, { processed: 1, adapted: 0, advanced_only: 0 });
  assertEquals(calls.claims, []);
  assertEquals(plans.get('plan-1')!.current_week, 1);
});

Deno.test('batch: catches up on several ended weeks in order', async () => {
  const w2 = week(2, { finished: [true, true], logs: [set('w2-squat', { weight_kg: 82.5 })] });
  w2.exercises[0].suggested_weight_kg = 82.5;
  const { deps, calls, plans } = setup({ now: AFTER_WEEK_2, weeks: { 1: easyWeek1(), 2: w2, 3: week(3) } });
  await handleBatch(deps);
  assertEquals(calls.claims, [1, 2]);
  assertEquals(plans.get('plan-1')!.current_week, 3);
  assert(calls.updates.some((u) => u.plan_exercise_id === 'w3-squat'));
});

Deno.test('batch: current_week never passes weeks_total', async () => {
  const { deps, plans } = setup({ now: new Date('2027-03-01T10:00:00Z'), plans: [plan({ pro: false })] });
  await handleBatch(deps);
  assertEquals(plans.get('plan-1')!.current_week, 4);
  assertEquals(plans.get('plan-1')!.last_adapted_week, 4);
});
