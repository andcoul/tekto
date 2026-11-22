// T151 — run with `node --test`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { equipmentErrors } from './seed-templates.js';

const library = JSON.parse(readFileSync(new URL('../exercises/exercises.json', import.meta.url), 'utf8'));
const equipmentOf = new Map(library.map((e) => [e.slug, e.equipment]));
const read = (slug) => JSON.parse(readFileSync(new URL(`./${slug}.json`, import.meta.url), 'utf8'));

test('a template may only use exercises whose equipment it requires (bodyweight is free)', () => {
  const body = { equipment_required: ['dumbbell'], sessions: [{ ref: 'A', exercises: [{ exercise_slug: 'x' }, { exercise_slug: 'y' }] }] };
  const errs = equipmentErrors('t.json', body, new Map([['x', ['dumbbell', 'bench']], ['y', ['bodyweight']]]));
  assert.deepEqual(errs, ["EQUIPMENT: t.json A: 'x' needs bench, not in equipment_required"]);
});

test('the three starter templates pass the equipment check against the library', () => {
  for (const slug of ['home-dumbbell-3x', 'beginner-full-body-3x', 'intermediate-ppl-4x']) {
    assert.deepEqual(equipmentErrors(`${slug}.json`, read(slug), equipmentOf), [], slug);
  }
});

test('the home template uses no barbell exercise', () => {
  const slugs = read('home-dumbbell-3x').sessions.flatMap((s) => s.exercises.map((e) => e.exercise_slug));
  for (const s of slugs) assert.ok(!(equipmentOf.get(s) ?? []).includes('barbell'), s);
});

// Plan library (FR-047, 2026-11-21): the programs a Pro user can choose.
import { readdirSync } from 'node:fs';
import { volumeErrors } from './seed-templates.js';

const musclesOf = new Map(library.map((e) => [e.slug, e.muscle_primary]));
const programs = readdirSync(new URL('.', import.meta.url))
  .filter((f) => f.endsWith('.json') && !f.startsWith('package'))
  .map((f) => read(f.replace(/\.json$/, '')))
  .filter((t) => t.catalog);

test('the plan library has nine programs with complete catalog entries in both languages', () => {
  assert.equal(programs.length, 9);
  assert.deepEqual(programs.map((p) => p.catalog.order).sort((a, b) => a - b), [1, 2, 3, 4, 5, 6, 7, 8, 9]);
  for (const p of programs) {
    for (const k of ['goal', 'image', 'summary_en', 'summary_fr']) assert.ok(p.catalog[k], `${p.slug}.catalog.${k}`);
    assert.ok(library.some((e) => e.slug === p.catalog.image), `${p.slug}: image ${p.catalog.image}`);
    assert.equal(p.days_per_week, p.sessions.length, p.slug);
    assert.equal(new Set(p.sessions.map((s) => s.day_of_week)).size, p.sessions.length, `${p.slug}: one session a day`);
  }
});

test('every program uses library exercises only, within its equipment and its level volume maximum', () => {
  const slugs = new Set(library.map((e) => e.slug));
  for (const p of programs) {
    for (const s of p.sessions) for (const e of s.exercises) assert.ok(slugs.has(e.exercise_slug), `${p.slug}: ${e.exercise_slug}`);
    assert.deepEqual(equipmentErrors(`${p.slug}.json`, p, equipmentOf), [], p.slug);
    assert.deepEqual(volumeErrors(`${p.slug}.json`, p, musclesOf), [], p.slug);
  }
});
