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
