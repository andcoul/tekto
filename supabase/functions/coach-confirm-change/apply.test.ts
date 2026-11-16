// T071 — applying a confirmed coach plan change (FR-018; Constitution IV; contracts/backend-api.md §3).
// Written before apply.ts (T074). In-memory ports, no network.
import { assertEquals } from 'jsr:@std/assert@1';
import type { CoachPlanChange } from '../_shared/types.ts';
import type { SwapExercise } from '../swap-exercise/handler.ts';
import { type ConfirmDeps, handleConfirm, type PendingMessage, type PlanExerciseRow } from './apply.ts';

const USER = 'user-1';
const NOW = new Date('2026-11-16T10:00:00Z');

function exercise(slug: string, over: Partial<SwapExercise> = {}): SwapExercise {
  return {
    id: `id-${slug}`, slug, name_en: slug, name_fr: slug, video_front_url: `https://v/${slug}.m3u8`,
    equipment: ['dumbbell'], muscle_primary: ['quadriceps'], contraindications: [], ...over,
  };
}

function row(id: string, over: Partial<PlanExerciseRow> = {}): PlanExerciseRow {
  return {
    id, session_id: 's-1', week_number: 1, exercise_slug: 'goblet-squat', sort_order: 0, sets: 3,
    reps_min: 8, reps_max: 12, rest_sec: 90, suggested_weight_kg: 20, ...over,
  };
}

function change(over: Partial<CoachPlanChange>): CoachPlanChange {
  return {
    type: 'exercise_swap', plan_exercise_id: 'pe-1', session_id: null, week_number: null, target_duration_min: null,
    old_exercise_slug: 'goblet-squat', new_exercise_slug: 'leg-press', new_weight_kg: null, new_reps_min: null,
    new_reps_max: null, reason_en: 'r', reason_fr: 'r', ...over,
  };
}

function setup(opts: { change?: CoachPlanChange | null; message?: Partial<PendingMessage>; rows?: PlanExerciseRow[] } = {}) {
  const exercises = new Map([
    ['goblet-squat', exercise('goblet-squat')],
    ['leg-press', exercise('leg-press', { equipment: ['machine'] })],
    ['split-squat', exercise('split-squat')],
    ['no-video-squat', exercise('no-video-squat', { video_front_url: null })],
    ['knee-killer', exercise('knee-killer', { contraindications: ['knee'] })],
  ]);
  const rows = new Map((opts.rows ?? [row('pe-1')]).map((r) => [r.id, { ...r }]));
  const message: PendingMessage = {
    id: 'm-1', user_id: USER, plan_change_proposed: opts.change === undefined ? change({}) : opts.change,
    plan_change_applied: false, plan_change_rejected_at: null, ...opts.message,
  };
  const calls = { applied: 0, rejected: [] as Date[], deleted: [] as string[], estimates: [] as [string, number][] };
  const deps: ConfirmDeps = {
    now: () => NOW,
    loadMessage: (id) => Promise.resolve(id === message.id ? message : null),
    loadActivePlanExercises: (userId) => Promise.resolve(userId === USER ? [...rows.values()] : []),
    updatePlanExercise: (id, patch) => {
      rows.set(id, { ...rows.get(id)!, ...patch });
      return Promise.resolve();
    },
    deletePlanExercises: (ids) => {
      for (const id of ids) rows.delete(id);
      calls.deleted.push(...ids);
      return Promise.resolve();
    },
    updateSessionEstimate: (sessionId, minutes) => {
      calls.estimates.push([sessionId, minutes]);
      return Promise.resolve();
    },
    markApplied: () => {
      calls.applied += 1;
      message.plan_change_applied = true;
      return Promise.resolve();
    },
    markRejected: (_id, at) => {
      calls.rejected.push(at);
      message.plan_change_rejected_at = at.toISOString();
      return Promise.resolve();
    },
    swap: {
      loadExercise: (id) => Promise.resolve([...exercises.values()].find((e) => e.id === id) ?? null),
      loadExerciseBySlug: (slug) => Promise.resolve(exercises.get(slug) ?? null),
      loadPlanExercise: (id) => {
        const r = rows.get(id);
        return Promise.resolve(r ? { id: r.id, exercise_slug: r.exercise_slug, user_id: USER, plan_status: 'active' } : null);
      },
      loadProfile: () => Promise.resolve({ equipment: ['dumbbell', 'machine'], limitations: ['knee'], tier: 'pro' }),
      applySwap: (id, slug) => {
        rows.set(id, { ...rows.get(id)!, exercise_slug: slug });
        return Promise.resolve();
      },
    },
  };
  return { deps, rows, calls, message };
}

const confirm = (deps: ConfirmDeps, confirmed = true) => handleConfirm(USER, { message_id: 'm-1', confirmed }, deps);

// ---- exercise_swap ----

Deno.test('exercise_swap replaces the exercise and marks the message applied', async () => {
  const { deps, rows, calls } = setup();
  const res = await confirm(deps);
  assertEquals(res.status, 200);
  assertEquals(res.body.applied, true);
  assertEquals(res.body.change_type, 'exercise_swap');
  assertEquals(rows.get('pe-1')!.exercise_slug, 'leg-press');
  assertEquals(res.body.updated_plan_exercises[0].exercise_slug, 'leg-press');
  assertEquals(calls.applied, 1);
});

Deno.test('exercise_swap to a video-less exercise → EXERCISE_NO_VIDEO, nothing applied (Constitution IV)', async () => {
  const { deps, rows, calls } = setup({ change: change({ new_exercise_slug: 'no-video-squat' }) });
  const res = await confirm(deps);
  assertEquals([res.status, res.body.code], [400, 'EXERCISE_NO_VIDEO']);
  assertEquals(rows.get('pe-1')!.exercise_slug, 'goblet-squat');
  assertEquals(calls.applied, 0);
});

Deno.test('exercise_swap to a contraindicated exercise → EXERCISE_NOT_ALLOWED', async () => {
  const { deps, calls } = setup({ change: change({ new_exercise_slug: 'knee-killer' }) });
  const res = await confirm(deps);
  assertEquals([res.status, res.body.code], [400, 'EXERCISE_NOT_ALLOWED']);
  assertEquals(calls.applied, 0);
});

// ---- session_shorten ----

Deno.test('session_shorten removes trailing exercises until the session fits, keeping ≥ 3', async () => {
  // 5 exercises × 3 sets × (45 + 90) s = 6.75 min each → 34 min in total.
  const rows = ['a', 'b', 'c', 'd', 'e'].map((id, i) => row(id, { sort_order: i, exercise_slug: `ex-${id}` }));
  const { deps, calls } = setup({
    rows,
    change: change({ type: 'session_shorten', plan_exercise_id: null, session_id: 's-1', target_duration_min: 21 }),
  });
  const res = await confirm(deps);
  assertEquals(res.status, 200);
  assertEquals(calls.deleted, ['e', 'd']);
  assertEquals(res.body.updated_plan_exercises.map((r: { plan_exercise_id: string }) => r.plan_exercise_id), ['a', 'b', 'c']);
  assertEquals(calls.estimates, [['s-1', 21]]);
});

Deno.test('session_shorten never goes below 3 exercises, even if the target is not reached', async () => {
  const rows = ['a', 'b', 'c', 'd'].map((id, i) => row(id, { sort_order: i }));
  const { deps, calls } = setup({
    rows,
    change: change({ type: 'session_shorten', plan_exercise_id: null, session_id: 's-1', target_duration_min: 5 }),
  });
  assertEquals((await confirm(deps)).status, 200);
  assertEquals(calls.deleted, ['d']);
});

Deno.test('session_shorten on a session outside the active plan → PLAN_TARGET_NOT_FOUND', async () => {
  const { deps } = setup({
    change: change({ type: 'session_shorten', plan_exercise_id: null, session_id: 'someone-else', target_duration_min: 20 }),
  });
  const res = await confirm(deps);
  assertEquals([res.status, res.body.code], [404, 'PLAN_TARGET_NOT_FOUND']);
});

// ---- deload ----

Deno.test('deload: sets −40 % (rounded, min 1) and weight −10 % for the target week only', async () => {
  const rows = [
    row('w1-a', { week_number: 1, sets: 5, suggested_weight_kg: 50 }),
    row('w1-b', { week_number: 1, sets: 1, suggested_weight_kg: 0 }),
    row('w1-c', { week_number: 1, sets: 3, suggested_weight_kg: null }),
    row('w2-a', { week_number: 2, sets: 5, suggested_weight_kg: 50 }),
  ];
  const { deps, rows: after } = setup({
    rows,
    change: change({ type: 'deload', plan_exercise_id: null, week_number: 1 }),
  });
  const res = await confirm(deps);
  assertEquals(res.status, 200);
  assertEquals([after.get('w1-a')!.sets, after.get('w1-a')!.suggested_weight_kg], [3, 45]);
  assertEquals([after.get('w1-b')!.sets, after.get('w1-b')!.suggested_weight_kg], [1, 0]);
  assertEquals([after.get('w1-c')!.sets, after.get('w1-c')!.suggested_weight_kg], [2, null]);
  assertEquals([after.get('w2-a')!.sets, after.get('w2-a')!.suggested_weight_kg], [5, 50], 'other weeks untouched');
  assertEquals(res.body.updated_plan_exercises.length, 3);
});

Deno.test('deload rounds the new weight down to 0.5 kg', async () => {
  const { deps, rows } = setup({
    rows: [row('pe-1', { suggested_weight_kg: 42.5 })],
    change: change({ type: 'deload', plan_exercise_id: null, week_number: 1 }),
  });
  await confirm(deps);
  assertEquals(rows.get('pe-1')!.suggested_weight_kg, 38); // 38.25 → 38
});

Deno.test('deload of a week with no exercises → PLAN_TARGET_NOT_FOUND', async () => {
  const { deps } = setup({ change: change({ type: 'deload', plan_exercise_id: null, week_number: 9 }) });
  assertEquals((await confirm(deps)).body.code, 'PLAN_TARGET_NOT_FOUND');
});

// ---- weight_adjustment ----

Deno.test('weight_adjustment sets weight and reps on one plan exercise', async () => {
  const { deps, rows } = setup({
    change: change({ type: 'weight_adjustment', new_weight_kg: 22.5, new_reps_min: 6, new_reps_max: 8 }),
  });
  const res = await confirm(deps);
  assertEquals(res.status, 200);
  const r = rows.get('pe-1')!;
  assertEquals([r.suggested_weight_kg, r.reps_min, r.reps_max], [22.5, 6, 8]);
});

Deno.test('weight_adjustment keeps fields the change leaves null', async () => {
  const { deps, rows } = setup({ change: change({ type: 'weight_adjustment', new_weight_kg: 25 }) });
  await confirm(deps);
  const r = rows.get('pe-1')!;
  assertEquals([r.suggested_weight_kg, r.reps_min, r.reps_max], [25, 8, 12]);
});

Deno.test('weight_adjustment with an invalid range or a negative weight → INVALID_CHANGE', async () => {
  for (const bad of [{ new_reps_min: 10, new_reps_max: 6 }, { new_weight_kg: -5 }, { new_reps_min: 0 }]) {
    const { deps, calls } = setup({ change: change({ type: 'weight_adjustment', ...bad }) });
    const res = await confirm(deps);
    assertEquals([res.status, res.body.code], [400, 'INVALID_CHANGE'], JSON.stringify(bad));
    assertEquals(calls.applied, 0);
  }
});

Deno.test('weight_adjustment on a plan exercise outside the active plan → PLAN_TARGET_NOT_FOUND', async () => {
  const { deps } = setup({ change: change({ type: 'weight_adjustment', plan_exercise_id: 'nope', new_weight_kg: 10 }) });
  assertEquals((await confirm(deps)).body.code, 'PLAN_TARGET_NOT_FOUND');
});

// ---- pending state ----

Deno.test('NO_PENDING_CHANGE when the message has no proposal, or it was applied or rejected', async () => {
  for (const opts of [
    { change: null },
    { message: { plan_change_applied: true } },
    { message: { plan_change_rejected_at: '2026-11-15T10:00:00Z' } },
  ]) {
    const { deps } = setup(opts);
    const res = await confirm(deps);
    assertEquals([res.status, res.body.code], [400, 'NO_PENDING_CHANGE'], JSON.stringify(opts));
  }
});

Deno.test('a second confirm of the same message → NO_PENDING_CHANGE', async () => {
  const { deps, calls } = setup();
  assertEquals((await confirm(deps)).status, 200);
  assertEquals((await confirm(deps)).body.code, 'NO_PENDING_CHANGE');
  assertEquals(calls.applied, 1);
});

Deno.test('confirmed: false records the rejection and changes nothing', async () => {
  const { deps, rows, calls } = setup();
  const res = await confirm(deps, false);
  assertEquals([res.status, res.body], [200, { applied: false }]);
  assertEquals(calls.rejected, [NOW]);
  assertEquals(rows.get('pe-1')!.exercise_slug, 'goblet-squat');
  assertEquals((await confirm(deps)).body.code, 'NO_PENDING_CHANGE', 'a rejected change cannot be applied later');
});

Deno.test("someone else's message → MESSAGE_NOT_FOUND (404)", async () => {
  const { deps } = setup({ message: { user_id: 'other-user' } });
  const res = await confirm(deps);
  assertEquals([res.status, res.body.code], [404, 'MESSAGE_NOT_FOUND']);
});

Deno.test('missing message_id or confirmed → INVALID_REQUEST', async () => {
  const { deps } = setup();
  assertEquals((await handleConfirm(USER, { message_id: 'm-1' }, deps)).body.code, 'INVALID_REQUEST');
  assertEquals((await handleConfirm(USER, { confirmed: true }, deps)).body.code, 'INVALID_REQUEST');
});
