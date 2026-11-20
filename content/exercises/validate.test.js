// T024 — run with `node --test`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateExercises } from './validate.js';

const ok = (slug, extra = {}) => ({
  slug,
  video_front_url: `https://v/${slug}.m3u8`,
  equipment: ['bodyweight'],
  video_duration_sec: 10,
  captions_en_url: `captions/${slug}_en.vtt`,
  captions_fr_url: `captions/${slug}_fr.vtt`,
  contraindications: [],
  variation_easier_slug: null,
  variation_harder_slug: null,
  ...extra,
});
const allCaptions = () => true;

test('a valid list passes in dev with count and lift-key warnings only', () => {
  const list = [ok('a', { variation_harder_slug: 'b' }), ok('b', { variation_easier_slug: 'a' })];
  const r = validateExercises(list, { production: false, captionExists: allCaptions });
  assert.deepEqual(r.errors, []);
  assert.equal(r.warnings.length, 2);
  assert.match(r.warnings[0], /at least 150/);
  assert.match(r.warnings[1], /form-check lifts/);
});

test('fewer than 150 exercises fails in production', () => {
  const r = validateExercises([ok('a')], { production: true, captionExists: allCaptions });
  assert.ok(r.errors.some((e) => /at least 150/.test(e)));
});

test('Video Gate: missing video_front_url is an error', () => {
  const r = validateExercises([ok('a', { video_front_url: null })], { production: false, captionExists: allCaptions });
  assert.ok(r.errors.some((e) => e.startsWith('VIDEO_GATE: a')));
});

test('captions: missing field or missing file is an error, per language', () => {
  const r = validateExercises([ok('a', { captions_fr_url: null }), ok('b')], {
    production: false,
    captionExists: (p) => p !== 'captions/b_en.vtt',
  });
  assert.ok(r.errors.includes('CAPTIONS: a has no captions_fr_url'));
  assert.ok(r.errors.includes('CAPTIONS: b caption file not found: captions/b_en.vtt'));
});

test('duration and contraindication vocabulary are enforced', () => {
  const r = validateExercises([ok('a', { video_duration_sec: 30, contraindications: ['toe'] })], {
    production: false,
    captionExists: allCaptions,
  });
  assert.ok(r.errors.some((e) => /4–15/.test(e)));
  assert.ok(r.errors.some((e) => /unknown contraindications toe/.test(e)));
});

test('unknown variation links are cleared with a warning in dev, an error in production', () => {
  const list = [ok('a', { variation_harder_slug: 'missing' }), ok('b', { variation_easier_slug: 'a' })];
  const dev = validateExercises(list, { production: false, captionExists: allCaptions });
  assert.deepEqual(dev.errors, []);
  assert.equal(dev.exercises[0].variation_harder_slug, null);
  assert.equal(dev.exercises[1].variation_easier_slug, 'a');
  const prod = validateExercises(list, { production: true, captionExists: allCaptions });
  assert.ok(prod.errors.some((e) => /'missing' is not in exercises.json/.test(e)));
});

test('duplicate slugs are an error', () => {
  const r = validateExercises([ok('a'), ok('a')], { production: false, captionExists: allCaptions });
  assert.ok(r.errors.includes('Duplicate slugs in exercises.json'));
});

// T143 — clarifications 2026-11-20 (FR-013, FR-014, FR-022).
const LIFTS = ['squat', 'deadlift', 'bench_press', 'overhead_press', 'row', 'lunge', 'hip_thrust', 'push_up'];
const sideOk = (slug, key) => ok(slug, { form_check_lift_key: key, video_side_url: `https://v/${slug}-side.m3u8` });
const fullLifts = () => LIFTS.map((k, i) => sideOk(`lift-${i}`, k));

test('equipment must come from the vocabulary', () => {
  const r = validateExercises([ok('a', { equipment: ['bodyweight', 'pull_up_bar'] }), ok('b', { equipment: ['trampoline'] })], {
    production: false,
    captionExists: allCaptions,
  });
  assert.ok(!r.errors.some((e) => e.startsWith('a:')));
  assert.ok(r.errors.some((e) => /b: unknown equipment trampoline/.test(e)));
  const none = validateExercises([ok('c', { equipment: [] })], { production: false, captionExists: allCaptions });
  assert.ok(none.errors.some((e) => /c: no equipment/.test(e)));
});

test('clip length may be 4 s but not 3 s', () => {
  const r = validateExercises([ok('a', { video_duration_sec: 4 }), ok('b', { video_duration_sec: 3 })], {
    production: false,
    captionExists: allCaptions,
  });
  assert.ok(!r.errors.some((e) => e.startsWith('a:')));
  assert.ok(r.errors.some((e) => /b: video_duration_sec must be 4–15/.test(e)));
});

test('every exercise needs at least one variation: warning in dev, error in production', () => {
  const list = [ok('a'), ok('b', { variation_easier_slug: 'a' })];
  const dev = validateExercises(list, { production: false, captionExists: allCaptions });
  assert.ok(dev.warnings.some((w) => /a: no easier or harder variation/.test(w)));
  assert.ok(!dev.warnings.some((w) => /b: no easier or harder variation/.test(w)));
  const prod = validateExercises(list, { production: true, captionExists: allCaptions });
  assert.ok(prod.errors.some((e) => /a: no easier or harder variation/.test(e)));
});

test('a variation link cleared as unknown no longer counts as a variation', () => {
  const dev = validateExercises([ok('a', { variation_harder_slug: 'missing' })], { production: false, captionExists: allCaptions });
  assert.ok(dev.warnings.some((w) => /a: no easier or harder variation/.test(w)));
});

test('all 8 form-check lifts must be in the library', () => {
  const missingLunge = fullLifts().filter((e) => e.form_check_lift_key !== 'lunge');
  const dev = validateExercises(missingLunge, { production: false, captionExists: allCaptions });
  assert.ok(dev.warnings.some((w) => /form-check lifts.*lunge/.test(w)));
  const prod = validateExercises(missingLunge, { production: true, captionExists: allCaptions });
  assert.ok(prod.errors.some((e) => /form-check lifts.*lunge/.test(e)));
  const all = validateExercises(fullLifts(), { production: false, captionExists: allCaptions });
  assert.ok(!all.warnings.some((w) => /form-check lifts/.test(w)));
});

test('form-check lifts and their variants need a second-angle video', () => {
  const list = [ok('front-squat'), ok('dumbbell-lunge', { form_check_lift_key: 'lunge' }), sideOk('push-up', 'push_up'), ok('plank')];
  const dev = validateExercises(list, { production: false, captionExists: allCaptions });
  assert.ok(dev.warnings.some((w) => /front-squat: no second-angle video/.test(w)));
  assert.ok(dev.warnings.some((w) => /dumbbell-lunge: no second-angle video/.test(w)));
  assert.ok(!dev.warnings.some((w) => /(push-up|plank): no second-angle video/.test(w)));
  const prod = validateExercises(list, { production: true, captionExists: allCaptions });
  assert.ok(prod.errors.some((e) => /front-squat: no second-angle video/.test(e)));
});
