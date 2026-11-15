// T013 — written before the plan-validator.ts rewrite (Constitution V).
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { validatePlan } from './plan-validator.ts';
import { ex, LIBRARY, plan, profile } from './test-fixtures.ts';
import type { ValidationResult } from './plan-draft.ts';

const codes = (r: ValidationResult) => [...new Set(r.errors.map((e) => e.code))].sort();

// Baseline: 3× (bench-press 5 sets + dumbbell-row 5 sets) (Mon/Wed/Fri) → chest 15 and lats 15 sets/week
// (push:pull 1.0), ~23 min/session, 4 weeks.
const session = (benchSets: number, rowSets = 5) => [ex('bench-press', { sets: benchSets }), ex('dumbbell-row', { sets: rowSets })];
const baseline = () => plan([session(5), session(5), session(5)]);
const p = profile();

Deno.test('baseline plan is valid for AI and template sources', () => {
  assertEquals(validatePlan(baseline(), p, LIBRARY, 'ai'), { valid: true, errors: [] });
  assertEquals(validatePlan(baseline(), p, LIBRARY, 'template').valid, true);
});

Deno.test('Video Gate: an exercise without a video is rejected', () => {
  const r = validatePlan(plan([[ex('cable-fly')]]), profile({ equipment: ['cable'] }), LIBRARY, 'template');
  assertEquals(codes(r), ['VIDEO_GATE']);
  assertEquals(r.errors[0].exercise_slug, 'cable-fly');
});

Deno.test('unknown exercise slugs are rejected', () => {
  assertEquals(codes(validatePlan(plan([[ex('made-up-move')]]), p, LIBRARY, 'template')), ['UNKNOWN_EXERCISE']);
});

Deno.test('exercises needing unavailable equipment are rejected', () => {
  const r = validatePlan(plan([[ex('barbell-squat')]]), profile({ equipment: ['dumbbell'] }), LIBRARY, 'template');
  assertEquals(codes(r), ['EQUIPMENT']);
});

Deno.test('exercises contraindicated by the user limitations are rejected', () => {
  const r = validatePlan(plan([[ex('barbell-squat')]]), profile({ limitations: ['knee'] }), LIBRARY, 'template');
  assertEquals(codes(r), ['CONTRAINDICATED']);
});

Deno.test('two consecutive days training the same muscle group are rejected', () => {
  const consecutive = plan([[ex('bench-press')], [ex('push-up')]], { days: [1, 2] });
  assertEquals(codes(validatePlan(consecutive, p, LIBRARY, 'template')), ['REST_DAYS']);
  const spaced = plan([[ex('bench-press')], [ex('push-up')]], { days: [1, 3] });
  assertEquals(validatePlan(spaced, p, LIBRARY, 'template').valid, true);
  const differentMuscles = plan([[ex('bench-press')], [ex('dumbbell-row')]], { days: [1, 2] });
  assertEquals(validatePlan(differentMuscles, p, LIBRARY, 'template').valid, true);
});

Deno.test('sessions longer than session_length_min + 10 are rejected', () => {
  // Each exercise: 3 sets × (45 s work + 90 s rest) = 6.75 min. Limit for 15 min = 25 min.
  const short = profile({ session_length_min: 15 });
  const three = plan([[ex('bench-press'), ex('dumbbell-row'), ex('goblet-squat')]]);
  assertEquals(validatePlan(three, short, LIBRARY, 'template').valid, true); // 21 min
  const four = plan([[ex('bench-press'), ex('dumbbell-row'), ex('goblet-squat'), ex('dumbbell-rdl')]]);
  assertEquals(codes(validatePlan(four, short, LIBRARY, 'template')), ['DURATION']); // 27 min
});

Deno.test('weeks_total must be between 4 and 12', () => {
  assertEquals(codes(validatePlan({ ...baseline(), weeks_total: 3 }, p, LIBRARY, 'template')), ['WEEKS']);
  assertEquals(codes(validatePlan({ ...baseline(), weeks_total: 13 }, p, LIBRARY, 'template')), ['WEEKS']);
});

Deno.test('the volume maximum applies to every plan source (FR-002a, Constitution III)', () => {
  // 30 chest sets/week is above the intermediate maximum (18); push:pull 30/15 = 2.0 stays in range.
  const tooMuch = plan([session(10), session(10), session(10)]);
  // ~34 min sessions: fits 60 min, so VOLUME is the only error.
  for (const source of ['ai', 'template', 'template_fallback'] as const) {
    assertEquals(codes(validatePlan(tooMuch, p, LIBRARY, source)), ['VOLUME'], source);
  }
});

Deno.test('the volume minimum applies to AI plans only', () => {
  // 6 chest and 6 lats sets/week: below the intermediate minimum (14), but templates trimmed
  // to short sessions cannot always reach it.
  const light = plan([session(2, 2), session(2, 2), session(2, 2)]);
  assertEquals(validatePlan(light, p, LIBRARY, 'template').valid, true);
  assertEquals(validatePlan(light, p, LIBRARY, 'template_fallback').valid, true);
  assertEquals(codes(validatePlan(light, p, LIBRARY, 'ai')), ['VOLUME']);
});

Deno.test('AI plans must keep weekly push:pull sets between 0.5 and 2.0', () => {
  // No pulling at all: 15 chest sets, 0 pull sets.
  const pushOnly = plan([[ex('bench-press', { sets: 5 })], [ex('bench-press', { sets: 5 })], [ex('bench-press', { sets: 5 })]]);
  assertEquals(codes(validatePlan(pushOnly, p, LIBRARY, 'ai')), ['BALANCE']);
  // 15 push vs 6 pull = 2.5 → too push-heavy.
  const pushHeavy = plan([session(5, 2), session(5, 2), session(5, 2)]);
  assertEquals(codes(validatePlan(pushHeavy, p, LIBRARY, 'ai')).includes('BALANCE'), true);
  // 6 push vs 15 pull = 0.4 → too pull-heavy.
  const pullHeavy = plan([session(2, 5), session(2, 5), session(2, 5)]);
  assertEquals(codes(validatePlan(pullHeavy, p, LIBRARY, 'ai')).includes('BALANCE'), true);
  // Exactly 2.0 is allowed (inclusive bound).
  assertEquals(codes(validatePlan(plan([session(10), session(10), session(10)]), p, LIBRARY, 'ai')).includes('BALANCE'), false);
  // Lower-body-only plans have no upper-body sets, so balance does not apply.
  const legs = plan([[ex('goblet-squat', { sets: 5 })], [ex('dumbbell-rdl', { sets: 5 })], [ex('goblet-squat', { sets: 5 })]]);
  assertEquals(codes(validatePlan(legs, profile({ limitations: [] }), LIBRARY, 'ai')).includes('BALANCE'), false);
  // Templates are not balance-checked.
  assertEquals(validatePlan(pushOnly, p, LIBRARY, 'template').valid, true);
});

Deno.test('AI plans below the level minimum for a trained major muscle are rejected', () => {
  // 6 chest sets/week is below the intermediate minimum (14).
  const tooLittle = plan([session(2, 2), session(2, 2), session(2, 2)]);
  const r = validatePlan(tooLittle, p, LIBRARY, 'ai');
  assertEquals(codes(r), ['VOLUME']);
  assert(r.errors[0].message.includes('chest'));
});

Deno.test('beginner and advanced volume bounds differ', () => {
  // 15 chest and 15 lats sets/week: above the beginner maximum (14).
  assertEquals(codes(validatePlan(baseline(), profile({ level: 'beginner' }), LIBRARY, 'ai')), ['VOLUME']);
  // 15 is below the advanced minimum (16).
  assertEquals(codes(validatePlan(baseline(), profile({ level: 'advanced' }), LIBRARY, 'ai')), ['VOLUME']);
});
