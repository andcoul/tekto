// T112 — written before starting-weights.ts (US1 scenario 3, FR-009).
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { startingWeightKg } from './starting-weights.ts';
import type { LibraryExercise } from './plan-draft.ts';

const ex = (slug: string, equipment: string[]): LibraryExercise =>
  ({ slug, equipment, muscle_primary: ['x'], video_front_url: 'v', contraindications: [] });

const squat = ex('barbell-squat', ['barbell']);
const goblet = ex('goblet-squat', ['dumbbell']);
const bench = ex('bench-press', ['barbell']);
const pushUp = ex('push-up', ['bodyweight']);
const pulldown = ex('lat-pulldown', ['cable']);

Deno.test('with a strength check: weight from the e1RM, scaled to the rep range at RPE ≤ 7', () => {
  // 100 kg × 5 → e1RM 116.7; 8–10 reps with 3 in reserve → 116.7 / (1 + 13/30) = 81.4 → round down to 80.
  const w = startingWeightKg(squat, { reps_min: 8, reps_max: 10 }, 'intermediate', { squat: { weight_kg: 100, reps: 5 } });
  assertEquals(w, 80);
});

Deno.test('related exercises use a fixed ratio of the matching lift, rounded to the equipment increment', () => {
  // goblet squat = 35 % of the squat e1RM → 116.7 × 0.35 / (1 + 15/30) = 27.2 → 27 kg (1 kg dumbbell steps).
  const w = startingWeightKg(goblet, { reps_min: 10, reps_max: 12 }, 'intermediate', { squat: { weight_kg: 100, reps: 5 } });
  assertEquals(w, 27);
});

Deno.test('strength check skipped: conservative defaults by level and equipment', () => {
  const reps = { reps_min: 8, reps_max: 12 };
  assertEquals(startingWeightKg(squat, reps, 'beginner', null), 20); // empty bar
  assertEquals(startingWeightKg(goblet, reps, 'beginner', null), 4);
  assertEquals(startingWeightKg(pulldown, reps, 'beginner', null), 15);
  assert(startingWeightKg(squat, reps, 'advanced', null) > startingWeightKg(squat, reps, 'beginner', null));
});

Deno.test('an "I don\'t know" lift falls back to defaults for that lift only', () => {
  const estimates = { bench_press: { weight_kg: 60, reps: 8 } }; // squat unknown
  assertEquals(startingWeightKg(squat, { reps_min: 8, reps_max: 12 }, 'beginner', estimates), 20);
  assert(startingWeightKg(bench, { reps_min: 8, reps_max: 12 }, 'beginner', estimates) > 20);
});

Deno.test('bodyweight exercises are 0 kg; barbell never below the empty bar; never negative', () => {
  assertEquals(startingWeightKg(pushUp, { reps_min: 8, reps_max: 12 }, 'advanced', { bench_press: { weight_kg: 100, reps: 5 } }), 0);
  assertEquals(startingWeightKg(squat, { reps_min: 15, reps_max: 20 }, 'beginner', { squat: { weight_kg: 20, reps: 1 } }), 20);
  const unknownSlug = ex('mystery-press', ['dumbbell']);
  assertEquals(startingWeightKg(unknownSlug, { reps_min: 8, reps_max: 12 }, 'beginner', { bench_press: { weight_kg: 60, reps: 8 } }), 4);
});

Deno.test('malformed estimates (zero or negative) are ignored', () => {
  assertEquals(startingWeightKg(squat, { reps_min: 8, reps_max: 12 }, 'beginner', { squat: { weight_kg: -10, reps: 5 } }), 20);
  assertEquals(startingWeightKg(squat, { reps_min: 8, reps_max: 12 }, 'beginner', { squat: { weight_kg: 100, reps: 0 } }), 20);
});
