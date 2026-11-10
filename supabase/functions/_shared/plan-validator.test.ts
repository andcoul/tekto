// T013 — written before the plan-validator.ts rewrite (Constitution V).
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { validatePlan } from './plan-validator.ts';
import { ex, LIBRARY, plan, profile } from './test-fixtures.ts';
import type { ValidationResult } from './plan-draft.ts';

const codes = (r: ValidationResult) => [...new Set(r.errors.map((e) => e.code))].sort();

// Baseline: 3× bench-press 5 sets (Mon/Wed/Fri) → chest 15 sets/week, ~12 min/session, 4 weeks.
const baseline = () => plan([[ex('bench-press', { sets: 5 })], [ex('bench-press', { sets: 5 })], [ex('bench-press', { sets: 5 })]]);
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

Deno.test('volume bounds apply to AI plans only', () => {
  // 30 chest sets/week is above the intermediate maximum (18).
  const tooMuch = plan([[ex('bench-press', { sets: 10 })], [ex('bench-press', { sets: 10 })], [ex('bench-press', { sets: 10 })]]);
  // ~23 min sessions: fits 60 min, so VOLUME is the only error.
  assertEquals(codes(validatePlan(tooMuch, p, LIBRARY, 'ai')), ['VOLUME']);
  assertEquals(validatePlan(tooMuch, p, LIBRARY, 'template').valid, true);
  assertEquals(validatePlan(tooMuch, p, LIBRARY, 'template_fallback').valid, true);
});

Deno.test('AI plans below the level minimum for a trained major muscle are rejected', () => {
  // 6 chest sets/week is below the intermediate minimum (14).
  const tooLittle = plan([[ex('bench-press', { sets: 2 })], [ex('bench-press', { sets: 2 })], [ex('bench-press', { sets: 2 })]]);
  const r = validatePlan(tooLittle, p, LIBRARY, 'ai');
  assertEquals(codes(r), ['VOLUME']);
  assert(r.errors[0].message.includes('chest'));
});

Deno.test('beginner and advanced volume bounds differ', () => {
  // 15 chest sets/week: inside beginner max? No — beginner max is 14.
  assertEquals(codes(validatePlan(baseline(), profile({ level: 'beginner' }), LIBRARY, 'ai')), ['VOLUME']);
  // 15 is below the advanced minimum (16).
  assertEquals(codes(validatePlan(baseline(), profile({ level: 'advanced' }), LIBRARY, 'ai')), ['VOLUME']);
});
