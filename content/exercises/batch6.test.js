// Batch 6 (2026-11-21): the pending exercises are complete and promote cleanly — run with `node --test`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { EQUIPMENT, LIMITATION_TAGS, validateExercises } from './validate.js';
import { expandBatch6 } from './pending-batch-6.js';
import { promoteEntry } from './promote.js';

const library = JSON.parse(readFileSync(new URL('./exercises.json', import.meta.url), 'utf8'));
const pending = expandBatch6();
const okClip = { checks: { ok: true, durationSec: 6.8 } };

test('no pending exercise duplicates a library slug or name', () => {
  const slugs = new Set(library.map((e) => e.slug));
  const names = new Set(library.map((e) => e.name_en.toLowerCase()));
  for (const e of pending) {
    assert.ok(!slugs.has(e.slug), e.slug);
    assert.ok(!names.has(e.name_en.toLowerCase()), e.name_en);
  }
  assert.equal(new Set(pending.map((e) => e.slug)).size, pending.length);
  assert.equal(new Set(pending.map((e) => e._clip)).size, pending.length);
});

test('every pending entry is complete in both languages and uses the vocabularies', () => {
  for (const e of pending) {
    assert.ok(e.name_en && e.name_fr, e.slug);
    assert.equal(e.cues_en.length, e.cues_fr.length, e.slug);
    assert.equal(e.common_mistakes_en.length, e.common_mistakes_fr.length, e.slug);
    assert.ok(e.equipment.every((x) => EQUIPMENT.includes(x)), e.slug);
    assert.ok(e.contraindications.every((x) => LIMITATION_TAGS.includes(x)), e.slug);
    assert.ok(e.variation_easier_slug || e.variation_harder_slug, `${e.slug} needs a variation`);
    assert.match(e._clip, /^(chest|back|legs|shoulders|arms|core|glutes)-[a-z0-9-]+\.mp4$/);
  }
});

test('at least half the clips have Black leads (research §16)', () => {
  assert.ok(pending.filter((e) => e._lead.startsWith('Black')).length * 2 >= pending.length);
});

test('library plus batch 6, once promoted, passes the validator with every variation link resolved', () => {
  const promoted = pending.map((p) => promoteEntry(p, okClip, () => true).entry);
  const r = validateExercises([...library, ...promoted], { production: false, captionExists: () => true });
  assert.deepEqual(r.errors, []);
  assert.ok(!r.warnings.some((w) => /unknown|not found/i.test(w)), r.warnings.join('\n'));
  assert.ok(library.length + promoted.length >= 140);
});

test('promotion needs a passed clip and both caption files', () => {
  const p = pending[0];
  assert.match(promoteEntry(p, undefined, () => true).error, /not in the ingest manifest/);
  assert.match(promoteEntry(p, { checks: { ok: false } }, () => true).error, /failed the clip checks/);
  assert.match(promoteEntry(p, okClip, (f) => !f.endsWith('_fr.vtt')).error, /missing caption/);
  const { entry } = promoteEntry(p, okClip, () => true);
  assert.equal(entry.video_duration_sec, 7);
  assert.ok(entry.video_front_url.includes(p.slug));
  assert.ok(Object.keys(entry).every((k) => !k.startsWith('_')));
});
