// ---------------------------------------------------------------------------
// T080 — PlanAdaptationService unit tests (Constitution V; FR-026)
// ---------------------------------------------------------------------------
// Run with: deno test supabase/functions/_shared/plan-adaptation.test.ts

import { assert, assertEquals, assertNotEquals } from 'jsr:@std/assert@1';
import { computeAdaptation, WeekData, PlanExerciseRow, SetLogRow } from './plan-adaptation.ts';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makePlanExercise(overrides: Partial<PlanExerciseRow> = {}): PlanExerciseRow {
  return {
    id: 'pe-001',
    reps_min: 5,
    reps_max: 8,
    rpe_target: 7,
    rir_target: null,
    suggested_weight_kg: 80,
    exercise_slug: 'barbell-squat',
    equipment: ['barbell'],
    ...overrides,
  };
}

function makeSetLog(overrides: Partial<SetLogRow> = {}): SetLogRow {
  return {
    id: `sl-${Math.random()}`,
    plan_exercise_id: 'pe-001',
    weight_kg: 80,
    reps: 6,
    rpe_actual: 7,
    workout_log_id: 'wl-001',
    ...overrides,
  };
}

function makeWeekData(
  peOverrides: Partial<PlanExerciseRow> = {},
  setLogOverrides: Partial<SetLogRow>[] = [{}, {}, {}],
  options: { plannedSessions?: number; completedSessions?: number; sessionEffort?: number | null } = {},
): WeekData {
  return {
    planExercise: makePlanExercise(peOverrides),
    setLogs: setLogOverrides.map(makeSetLog),
    plannedSessionCount: options.plannedSessions ?? 3,
    completedSessionCount: options.completedSessions ?? 3,
    sessionEffort: options.sessionEffort ?? null,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

Deno.test('(a) progresses weight when all reps hit at ≤ RPE target and increment ≤ 10% e1RM', () => {
  // e1RM = 80 * (1 + 6/30) = 96. 10% = 9.6. Barbell increment = 2.5. 2.5 ≤ 9.6 → primary path.
  const data = makeWeekData(
    { suggested_weight_kg: 80, rpe_target: 7 },
    [
      { weight_kg: 80, reps: 6, rpe_actual: 6.5 },
      { weight_kg: 80, reps: 6, rpe_actual: 7 },
      { weight_kg: 80, reps: 6, rpe_actual: 7 },
    ],
  );

  const events = computeAdaptation([data]);
  assertEquals(events.length, 1);
  assertEquals(events[0].field, 'suggested_weight_kg');
  assertEquals(events[0].newValue, 82.5);
  assertEquals(events[0].oldValue, 80);
});

Deno.test('(b) progresses reps_max instead when increment would exceed 10% e1RM', () => {
  // Very light weight → e1RM is small → 2.5 kg > 10%
  // e1RM = 10 * (1 + 6/30) = 12. 10% = 1.2. 2.5 > 1.2 → alternative path.
  const data = makeWeekData(
    { suggested_weight_kg: 10, rpe_target: 7, reps_max: 8 },
    [
      { weight_kg: 10, reps: 6, rpe_actual: 6 },
      { weight_kg: 10, reps: 6, rpe_actual: 7 },
      { weight_kg: 10, reps: 6, rpe_actual: 6 },
    ],
  );

  const events = computeAdaptation([data]);
  assertEquals(events.length, 1);
  assertEquals(events[0].field, 'reps_max');
  assertEquals(events[0].newValue, 9); // reps_max + 1
});

Deno.test('(c) maintains (no event) when 2+ sessions missed', () => {
  const data = makeWeekData(
    {},
    [{ weight_kg: 80, reps: 6, rpe_actual: 7 }],
    { plannedSessions: 4, completedSessions: 2 }, // 2 missed
  );

  const events = computeAdaptation([data]);
  assertEquals(events.length, 0);
});

Deno.test('(d) reduces weight when avg RPE exceeds target by > 1', () => {
  // rpe_target = 7, avg_rpe = 9 → reduce
  const data = makeWeekData(
    { suggested_weight_kg: 80, rpe_target: 7 },
    [
      { weight_kg: 80, reps: 5, rpe_actual: 9 },
      { weight_kg: 80, reps: 5, rpe_actual: 9 },
      { weight_kg: 80, reps: 5, rpe_actual: 9 },
    ],
  );

  const events = computeAdaptation([data]);
  assertEquals(events.length, 1);
  assertEquals(events[0].field, 'suggested_weight_kg');
  assertEquals(events[0].newValue, 77.5); // 80 - 2.5
});

Deno.test('(e) handles edge case of zero completed sets in a session', () => {
  const data: WeekData = {
    planExercise: makePlanExercise(),
    setLogs: [], // no sets logged
    plannedSessionCount: 3,
    completedSessionCount: 3,
    sessionEffort: null,
  };

  const events = computeAdaptation([data]);
  // No data → no change
  assertEquals(events.length, 0);
});

Deno.test('returns empty array when all exercises maintain', () => {
  // 1 missed session out of 3 (< 2 missed) + rpe_actual = rpe_target exactly
  // No progression (rpe === target, not strictly below)
  // Actually: avgRpe = rpe_target exactly → no reduce; allRepsHit = true; avgRpe <= rpe_target → progress
  // But we set rpe_actual slightly above target to trigger maintain

  // Let's test with avgRpe = rpe_target + 0.5 (not > target+1 so no reduce; not ≤ target so no progress)
  const data = makeWeekData(
    { rpe_target: 7, suggested_weight_kg: 80 },
    [
      { reps: 5, rpe_actual: 7.5 },
      { reps: 5, rpe_actual: 7.5 },
    ],
  );

  const events = computeAdaptation([data]);
  // rpe_actual (7.5) > rpe_target (7) → allRepsHit check doesn't matter; avgRpe = 7.5, not > 8
  // → no event (maintain zone)
  assertEquals(events.length, 0);
});

Deno.test('(c) 2+ missed sessions never progress, even when every set was easy', () => {
  const easy = [{ weight_kg: 80, reps: 8, rpe_actual: 5 }, { weight_kg: 80, reps: 8, rpe_actual: 5 }];
  const events = computeAdaptation([makeWeekData({}, easy, { plannedSessions: 4, completedSessions: 2 })]);
  assertEquals(events.filter((e) => e.newValue > e.oldValue), []);
});

Deno.test('(c) 2+ missed sessions still reduce a lift that was far too hard', () => {
  const hard = [{ weight_kg: 80, reps: 5, rpe_actual: 9.5 }];
  const events = computeAdaptation([makeWeekData({}, hard, { plannedSessions: 4, completedSessions: 2 })]);
  assertEquals(events.map((e) => [e.field, e.newValue]), [['suggested_weight_kg', 77.5]]);
});

Deno.test('(e) zero completed sessions in the week → no change for any exercise', () => {
  const week = [makeWeekData({ id: 'a' }, [], { completedSessions: 0 }), makeWeekData({ id: 'b' }, [], { completedSessions: 0 })];
  assertEquals(computeAdaptation(week), []);
});

Deno.test('(f) all reps failed — every set below reps_min → weight reduced one increment, never progressed', () => {
  const failed = [
    { weight_kg: 80, reps: 3, rpe_actual: 7 },
    { weight_kg: 80, reps: 2, rpe_actual: 7 },
    { weight_kg: 80, reps: 3, rpe_actual: 6 },
  ];
  const events = computeAdaptation([makeWeekData({ reps_min: 5, rpe_target: 7 }, failed)]);
  assertEquals(events.map((e) => [e.field, e.oldValue, e.newValue]), [['suggested_weight_kg', 80, 77.5]]);
});

Deno.test('a session rated too hard (effort > target + 1) reduces its exercises at the weekly review (FR-026, US5/AC3)', () => {
  const onTarget = [{ weight_kg: 80, reps: 6, rpe_actual: null }, { weight_kg: 80, reps: 6, rpe_actual: null }];
  const events = computeAdaptation([makeWeekData({ rpe_target: 7 }, onTarget, { sessionEffort: 9 })]);
  assertEquals(events.map((e) => [e.field, e.newValue]), [['suggested_weight_kg', 77.5]]);
});

Deno.test('an RIR target is read as RPE = 10 − RIR', () => {
  // rir_target 2 → RPE 8; sets at RPE 8 with all reps → progress.
  const sets = [{ weight_kg: 80, reps: 6, rpe_actual: 8 }, { weight_kg: 80, reps: 6, rpe_actual: 8 }];
  const events = computeAdaptation([makeWeekData({ rpe_target: null, rir_target: 2 }, sets)]);
  assertEquals(events.map((e) => [e.field, e.newValue]), [['suggested_weight_kg', 82.5]]);
});

Deno.test('bodyweight exercises progress reps, and are held (not reduced below 0) when too hard', () => {
  const easy = [{ weight_kg: 0, reps: 12, rpe_actual: 6 }, { weight_kg: 0, reps: 12, rpe_actual: 6 }];
  const up = computeAdaptation([makeWeekData({ equipment: ['bodyweight'], suggested_weight_kg: 0, reps_min: 8, reps_max: 12 }, easy)]);
  assertEquals(up.map((e) => [e.field, e.newValue]), [['reps_max', 13]]);

  const hard = [{ weight_kg: 0, reps: 8, rpe_actual: 9.5 }];
  assertEquals(computeAdaptation([makeWeekData({ equipment: ['bodyweight'], suggested_weight_kg: 0 }, hard)]), []);
});

Deno.test('dumbbell exercises move by 1 kg; the increment follows the exercise equipment', () => {
  const sets = [{ weight_kg: 20, reps: 10, rpe_actual: 6 }, { weight_kg: 20, reps: 10, rpe_actual: 6 }];
  const events = computeAdaptation([makeWeekData({ equipment: ['dumbbell'], suggested_weight_kg: 20, reps_min: 8, reps_max: 12 }, sets)]);
  assertEquals(events.map((e) => [e.field, e.newValue]), [['suggested_weight_kg', 21]]);
});

Deno.test('every event carries deterministic EN and FR reasons', () => {
  const sets = [{ weight_kg: 80, reps: 6, rpe_actual: 7 }];
  const a = computeAdaptation([makeWeekData({}, sets)]);
  const b = computeAdaptation([makeWeekData({}, sets)]);
  assertEquals(a, b);
  for (const e of a) {
    assert(e.reasonEn.length > 0 && e.reasonFr.length > 0);
    assertNotEquals(e.reasonEn, e.reasonFr);
  }
});
