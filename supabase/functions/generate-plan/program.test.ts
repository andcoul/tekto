// FR-047 (2026-11-21): a Pro user picks a program from the plan library.
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { type FlowInput, runGeneratePlan } from './flow.ts';
import { type LibraryExercise, libraryFrom } from '../_shared/plan-draft.ts';
import { validatePlan } from '../_shared/plan-validator.ts';
import type { PlanTemplateDef } from '../_shared/template-plan-builder.ts';

const dir = new URL('../../../content/templates/', import.meta.url);
const TEMPLATES: PlanTemplateDef[] = [...Deno.readDirSync(dir)]
  .filter((f) => f.name.endsWith('.json') && !f.name.startsWith('package'))
  .map((f) => JSON.parse(Deno.readTextFileSync(new URL(f.name, dir))));
const PROGRAMS = TEMPLATES.filter((t) => t.catalog).map((t) => t.slug);
const LIBRARY = libraryFrom(JSON.parse(Deno.readTextFileSync(new URL('../../../content/exercises/exercises.json', import.meta.url))) as LibraryExercise[]);
const GYM = ['barbell', 'dumbbell', 'cable', 'machine', 'bands', 'pull_up_bar', 'dip_station', 'bench', 'bodyweight'];

const input = (programSlug: string, o: Partial<FlowInput['profile']> = {}, isPro = true): FlowInput => ({
  profile: {
    goal: 'muscle', level: 'intermediate', equipment: GYM, limitations: [], session_length_min: 60,
    days_per_week: 3, strength_estimates: null, ...o,
  },
  isPro,
  consentAt: '2026-11-10T09:00:00Z',
  hasActivePlan: true,
  forceRegenerate: true,
  programSlug,
});
const deps = {
  templates: TEMPLATES,
  library: LIBRARY,
  generateAiPlan: () => Promise.reject(new Error('a program never calls the AI')),
  nowMs: () => 0,
};

Deno.test('the library offers nine programs', () => assertEquals(PROGRAMS.length, 9));

Deno.test('a free user cannot start a program', async () => {
  const r = await runGeneratePlan(input('bro-split-5x', {}, false), deps);
  assert(!r.ok);
  assertEquals([r.status, r.code], [402, 'PRO_REQUIRED']);
});

Deno.test('an unknown slug, or a starter template that is not in the library, is not found', async () => {
  for (const slug of ['nope', 'intermediate-ppl-4x']) {
    const r = await runGeneratePlan(input(slug), deps);
    assert(!r.ok);
    assertEquals(r.code, 'PROGRAM_NOT_FOUND', slug);
  }
});

Deno.test('every program builds a valid plan for gym users of every level and session length', async () => {
  for (const slug of PROGRAMS) {
    for (const [level, minutes] of [['beginner', 45], ['intermediate', 60], ['advanced', 75], ['intermediate', 30]] as const) {
      const r = await runGeneratePlan(input(slug, { level, session_length_min: minutes }), deps);
      assert(r.ok, `${slug} ${level} ${minutes} min: ${!r.ok && r.errors?.join(' | ')}`);
      assertEquals([r.source, r.template_slug], ['template', slug]);
      const days = new Set(r.plan.sessions.map((s) => s.day_of_week));
      assertEquals(days.size, TEMPLATES.find((t) => t.slug === slug)!.sessions.length, `${slug}: keeps its own days`);
      assert(validatePlan(r.plan, input(slug, { level, session_length_min: minutes }).profile, LIBRARY, 'template').valid);
    }
  }
});

Deno.test('a program is fitted to limitations: no knee-contraindicated exercise for a knee limitation', async () => {
  const r = await runGeneratePlan(input('bro-split-5x', { limitations: ['knee'] }), deps);
  assert(r.ok);
  for (const s of r.plan.sessions) {
    for (const e of s.exercises) assert(!LIBRARY.get(e.exercise_slug)!.contraindications.includes('knee'), e.exercise_slug);
  }
});

Deno.test('a home dumbbell user gets each program adapted to dumbbells, or a clear refusal', async () => {
  for (const slug of PROGRAMS) {
    const r = await runGeneratePlan(input(slug, { equipment: ['dumbbell', 'bench', 'bodyweight'] }), deps);
    if (r.ok) {
      for (const s of r.plan.sessions) {
        for (const e of s.exercises) {
          assert(LIBRARY.get(e.exercise_slug)!.equipment.every((q) => ['dumbbell', 'bench', 'bodyweight'].includes(q)), `${slug}: ${e.exercise_slug}`);
        }
      }
    } else {
      assertEquals([r.status, r.code], [422, 'PROGRAM_NOT_SUITABLE'], slug);
      assert(r.errors && r.errors.length > 0);
    }
  }
});
