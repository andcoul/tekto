// T024 — run with `node --test`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { validateExercises } from './validate.js';

const ok = (slug, extra = {}) => ({
  slug,
  video_front_url: `https://v/${slug}.m3u8`,
  video_duration_sec: 10,
  captions_en_url: `captions/${slug}_en.vtt`,
  captions_fr_url: `captions/${slug}_fr.vtt`,
  contraindications: [],
  variation_easier_slug: null,
  variation_harder_slug: null,
  ...extra,
});
const allCaptions = () => true;

test('a valid list passes in dev with a count warning only', () => {
  const r = validateExercises([ok('a'), ok('b')], { production: false, captionExists: allCaptions });
  assert.deepEqual(r.errors, []);
  assert.equal(r.warnings.length, 1);
  assert.match(r.warnings[0], /at least 150/);
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
  assert.ok(r.errors.some((e) => /5–15/.test(e)));
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
