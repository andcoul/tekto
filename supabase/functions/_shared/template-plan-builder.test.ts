// T030 — written before template-plan-builder.ts (research §11). Uses the real content files.
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { type BuilderProfile, buildTemplatePlan, type PlanTemplateDef, selectTemplateSlug } from './template-plan-builder.ts';
import { estimateSessionMinutes, type LibraryExercise, libraryFrom } from './plan-draft.ts';
import { validatePlan } from './plan-validator.ts';

const read = (path: string) => JSON.parse(Deno.readTextFileSync(new URL(path, import.meta.url)));
const TEMPLATES: PlanTemplateDef[] = ['beginner-full-body-3x', 'home-dumbbell-3x', 'intermediate-ppl-4x']
  .map((s) => read(`../../../content/templates/${s}.json`));
const LIBRARY = libraryFrom(read('../../../content/exercises/exercises.json') as LibraryExercise[]);

const profile = (o: Partial<BuilderProfile> = {}): BuilderProfile => ({
  goal: 'muscle',
  level: 'intermediate',
  equipment: ['barbell', 'dumbbell', 'cable', 'bodyweight'],
  limitations: [],
  session_length_min: 60,
  days_per_week: 3,
  strength_estimates: null,
  ...o,
});

const week1 = (r: ReturnType<typeof buildTemplatePlan>) => r.plan.sessions.filter((s) => s.week_number === 1);
const slugs = (r: ReturnType<typeof buildTemplatePlan>) => new Set(r.plan.sessions.flatMap((s) => s.exercises.map((e) => e.exercise_slug)));

Deno.test('template selection: equipment first, then level, then goal', () => {
  assertEquals(selectTemplateSlug(profile({ equipment: ['dumbbell', 'bodyweight'] })), 'home-dumbbell-3x');
  assertEquals(selectTemplateSlug(profile({ level: 'beginner' })), 'beginner-full-body-3x');
  assertEquals(selectTemplateSlug(profile({ goal: 'strength' })), 'intermediate-ppl-4x');
  assertEquals(selectTemplateSlug(profile({ level: 'advanced', goal: 'muscle' })), 'intermediate-ppl-4x');
  assertEquals(selectTemplateSlug(profile({ goal: 'general_fitness' })), 'beginner-full-body-3x');
  assertEquals(selectTemplateSlug(profile({ goal: 'fat_loss' })), 'beginner-full-body-3x');
  // A beginner without a barbell still gets the dumbbell template (equipment wins).
  assertEquals(selectTemplateSlug(profile({ level: 'beginner', equipment: ['dumbbell'] })), 'home-dumbbell-3x');
});

Deno.test('days per week: 1, 2, 3, 4 sessions; 5–7 capped at 4 with a notice', () => {
  const dumbbell = { equipment: ['dumbbell', 'bodyweight'] };
  for (const [days, expected] of [[1, 1], [2, 2], [3, 3], [4, 4], [5, 4], [6, 4], [7, 4]]) {
    const r = buildTemplatePlan(TEMPLATES, profile({ ...dumbbell, days_per_week: days }), LIBRARY);
    assertEquals(week1(r).length, expected, `days=${days}`);
    assertEquals(r.notices.includes('free_plan_days_capped'), days >= 5, `notice for days=${days}`);
  }
});

Deno.test('4 days from a 3-day template repeats session A on Sunday', () => {
  const r = buildTemplatePlan(TEMPLATES, profile({ equipment: ['dumbbell', 'bodyweight'], days_per_week: 4 }), LIBRARY);
  const days = week1(r).map((s) => s.day_of_week);
  assertEquals(days, [1, 3, 5, 7]);
  assertEquals(week1(r)[3].name_en, week1(r)[0].name_en);
});

Deno.test('PPL: 4 days uses all 4 sessions, 3 days push/pull/legs, 1–2 days switch to full body', () => {
  const ppl = (days: number) => buildTemplatePlan(TEMPLATES, profile({ goal: 'strength', days_per_week: days }), LIBRARY);
  assertEquals(ppl(4).template_slug, 'intermediate-ppl-4x');
  assertEquals(week1(ppl(4)).length, 4);
  assertEquals(week1(ppl(3)).map((s) => s.name_en.split(' ')[0]), ['Push', 'Pull', 'Legs']);
  assertEquals(ppl(2).template_slug, 'beginner-full-body-3x');
});

Deno.test('the week pattern is repeated for weeks_total weeks', () => {
  const r = buildTemplatePlan(TEMPLATES, profile(), LIBRARY);
  assertEquals(r.plan.weeks_total, 8);
  assertEquals(r.plan.sessions.length, 8 * week1(r).length);
  assertEquals(new Set(r.plan.sessions.map((s) => s.week_number)).size, 8);
});

Deno.test('sessions fit the chosen length; ≥ 3 exercises kept, then sets and rest reduced', () => {
  for (const minutes of [15, 30, 45, 60]) {
    const r = buildTemplatePlan(TEMPLATES, profile({ session_length_min: minutes }), LIBRARY);
    for (const s of week1(r)) {
      assert(estimateSessionMinutes(s.exercises) <= minutes, `${minutes} min: '${s.name_en}' is ${estimateSessionMinutes(s.exercises)} min`);
      assert(s.exercises.length >= 3, `${minutes} min: '${s.name_en}' kept ${s.exercises.length} exercises`);
      for (const e of s.exercises) {
        assert(e.sets >= 2 && e.rest_sec >= 60, `${minutes} min: ${e.exercise_slug} sets ${e.sets}, rest ${e.rest_sec}`);
      }
    }
  }
});

Deno.test('dumbbell-only users never get barbell or cable exercises', () => {
  const r = buildTemplatePlan(TEMPLATES, profile({ equipment: ['dumbbell', 'bodyweight'] }), LIBRARY);
  for (const slug of slugs(r)) {
    const equipment = LIBRARY.get(slug)!.equipment;
    assert(equipment.every((e) => e === 'dumbbell' || e === 'bodyweight'), `${slug} needs ${equipment}`);
  }
});

Deno.test('limitations: contraindicated exercises are substituted or dropped', () => {
  const r = buildTemplatePlan(TEMPLATES, profile({ limitations: ['knee', 'lower_back'] }), LIBRARY);
  for (const slug of slugs(r)) {
    const tags = LIBRARY.get(slug)!.contraindications;
    assert(!tags.includes('knee') && !tags.includes('lower_back'), `${slug} is contraindicated`);
  }
});

Deno.test('every exercise gets a starting weight', () => {
  const r = buildTemplatePlan(TEMPLATES, profile({ level: 'beginner', strength_estimates: { squat: { weight_kg: 60, reps: 8 } } }), LIBRARY);
  for (const s of r.plan.sessions) {
    for (const e of s.exercises) assert(typeof e.suggested_weight_kg === 'number' && e.suggested_weight_kg >= 0, e.exercise_slug);
  }
});

Deno.test('every built plan passes the shared validator (FR-002a)', () => {
  const equipmentSets = [['dumbbell', 'bodyweight'], ['barbell', 'dumbbell', 'cable', 'bodyweight'], ['dumbbell']];
  for (const equipment of equipmentSets) {
    for (const level of ['beginner', 'intermediate', 'advanced'] as const) {
      for (const goal of ['muscle', 'strength', 'general_fitness'] as const) {
        for (const days of [1, 2, 3, 4, 6]) {
          for (const minutes of [15, 45, 90]) {
            for (const limitations of [[], ['knee'], ['shoulder', 'lower_back']] as const) {
              const p = profile({ equipment, level, goal, days_per_week: days, session_length_min: minutes, limitations: [...limitations] });
              const r = buildTemplatePlan(TEMPLATES, p, LIBRARY);
              const v = validatePlan(r.plan, p, LIBRARY, 'template');
              assert(v.valid, `${JSON.stringify(p)} → ${v.errors.map((e) => e.message).join('; ')}`);
            }
          }
        }
      }
    }
  }
});

Deno.test('quickstart Scenario 1: dumbbell-only intermediate, knee, 4 days, 45 min', () => {
  const p = profile({ equipment: ['dumbbell', 'bodyweight'], limitations: ['knee'], days_per_week: 4, session_length_min: 45 });
  const r = buildTemplatePlan(TEMPLATES, p, LIBRARY);
  assertEquals(r.template_slug, 'home-dumbbell-3x');
  assertEquals(week1(r).length, 4);
  for (const s of week1(r)) assert(estimateSessionMinutes(s.exercises) <= 45);
  for (const slug of slugs(r)) {
    assert(!LIBRARY.get(slug)!.equipment.includes('barbell'), slug);
    assert(!LIBRARY.get(slug)!.contraindications.includes('knee'), slug);
  }
  assert(validatePlan(r.plan, p, LIBRARY, 'template').valid);
});
