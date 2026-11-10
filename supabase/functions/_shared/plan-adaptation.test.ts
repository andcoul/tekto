// ---------------------------------------------------------------------------
// T091 — PlanAdaptationService unit tests
// ---------------------------------------------------------------------------
// Run with: deno test supabase/functions/_shared/plan-adaptation.test.ts

import { assertEquals, assertNotEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
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
    suggested_weight_kg: 80,
    exercise_id: 'ex-001',
    equipment: 'barbell',
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
  options: { plannedSessions?: number; completedSessions?: number } = {},
): WeekData {
  return {
    planExercise: makePlanExercise(peOverrides),
    setLogs: setLogOverrides.map(makeSetLog),
    plannedSessionCount: options.plannedSessions ?? 3,
    completedSessionCount: options.completedSessions ?? 3,
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
