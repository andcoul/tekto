// T120 — written before handler.ts (FR-028, Constitution IV). Swap is available to every tier
// and is rule-based: no Claude client is even passed in.
import { assertEquals } from 'jsr:@std/assert@1';
import { handleSwap, type SwapDeps, type SwapExercise } from './handler.ts';
import type { LimitationTag } from '../_shared/types.ts';

const ex = (id: string, o: Partial<SwapExercise> = {}): SwapExercise => ({
  id, slug: id, name_en: id, name_fr: id, video_front_url: `https://video.test/${id}.m3u8`,
  equipment: ['dumbbell'], muscle_primary: ['quadriceps', 'glutes'], contraindications: [], ...o,
});

const EXERCISES: Record<string, SwapExercise> = {
  'goblet-squat': ex('goblet-squat', { contraindications: ['knee'] }),
  'dumbbell-lunge': ex('dumbbell-lunge'),
  'barbell-squat': ex('barbell-squat', { equipment: ['barbell'] }),
  'step-up-no-video': ex('step-up-no-video', { video_front_url: null }),
  'split-squat-knee': ex('split-squat-knee', { contraindications: ['knee'] }),
  'dumbbell-row': ex('dumbbell-row', { muscle_primary: ['lats'] }),
};

function deps(o: { owner?: string; status?: string; limitations?: LimitationTag[]; tier?: 'free' | 'pro' } = {}) {
  const applied: Array<[string, string]> = [];
  const d: SwapDeps = {
    loadExercise: (id) => Promise.resolve(EXERCISES[id] ?? null),
    loadExerciseBySlug: (slug) => Promise.resolve(Object.values(EXERCISES).find((e) => e.slug === slug) ?? null),
    loadPlanExercise: (id) =>
      Promise.resolve(id === 'pe-1' ? { id, exercise_slug: 'goblet-squat', user_id: o.owner ?? 'u1', plan_status: o.status ?? 'active' } : null),
    loadProfile: () => Promise.resolve({ equipment: ['dumbbell', 'bodyweight'], limitations: o.limitations ?? [], tier: o.tier ?? 'free' }),
    applySwap: (pe, ex) => {
      applied.push([pe, ex]);
      return Promise.resolve();
    },
  };
  return { d, applied };
}

const swap = (newId: string, d: SwapDeps, userId = 'u1') => handleSwap(userId, { plan_exercise_id: 'pe-1', new_exercise_id: newId }, d);

Deno.test('a free user can swap; the response follows the contract', async () => {
  const { d, applied } = deps({ tier: 'free' });
  const r = await swap('dumbbell-lunge', d);
  assertEquals(r.status, 200);
  assertEquals(r.body, { plan_exercise_id: 'pe-1', new_exercise: { id: 'dumbbell-lunge', slug: 'dumbbell-lunge', name_en: 'dumbbell-lunge', name_fr: 'dumbbell-lunge' } });
  assertEquals(applied, [['pe-1', 'dumbbell-lunge']]);
});

Deno.test('the app can name the target by slug (it caches exercises by slug)', async () => {
  const { d, applied } = deps();
  const r = await handleSwap('u1', { plan_exercise_id: 'pe-1', new_exercise_slug: 'dumbbell-lunge' }, d);
  assertEquals(r.status, 200);
  assertEquals(applied, [['pe-1', 'dumbbell-lunge']]);
});

Deno.test('never PRO_REQUIRED, for any tier', async () => {
  for (const tier of ['free', 'pro'] as const) {
    const r = await swap('dumbbell-lunge', deps({ tier }).d);
    assertEquals(r.status, 200, tier);
  }
});

Deno.test('Video Gate: a target without video is rejected with EXERCISE_NO_VIDEO', async () => {
  const { d, applied } = deps();
  const r = await swap('step-up-no-video', d);
  assertEquals([r.status, r.body.code], [400, 'EXERCISE_NO_VIDEO']);
  assertEquals(applied, []);
});

Deno.test('a target needing unavailable equipment or contraindicated is EXERCISE_NOT_ALLOWED', async () => {
  const equipment = await swap('barbell-squat', deps().d);
  assertEquals([equipment.status, equipment.body.code], [400, 'EXERCISE_NOT_ALLOWED']);
  const knee = await swap('split-squat-knee', deps({ limitations: ['knee'] }).d);
  assertEquals([knee.status, knee.body.code], [400, 'EXERCISE_NOT_ALLOWED']);
});

Deno.test('the target must share a primary muscle with the current exercise', async () => {
  const r = await swap('dumbbell-row', deps().d);
  assertEquals([r.status, r.body.code], [400, 'EXERCISE_NOT_EQUIVALENT']);
});

Deno.test('ownership, active plan and existence checks', async () => {
  assertEquals((await swap('dumbbell-lunge', deps({ owner: 'someone-else' }).d)).status, 403);
  assertEquals((await swap('dumbbell-lunge', deps({ status: 'archived' }).d)).body.code, 'PLAN_NOT_ACTIVE');
  assertEquals((await swap('nope', deps().d)).body.code, 'EXERCISE_NOT_FOUND');
  const missingPe = await handleSwap('u1', { plan_exercise_id: 'pe-9', new_exercise_id: 'dumbbell-lunge' }, deps().d);
  assertEquals([missingPe.status, missingPe.body.code], [404, 'PLAN_EXERCISE_NOT_FOUND']);
  const bad = await handleSwap('u1', { plan_exercise_id: '', new_exercise_id: 'dumbbell-lunge' }, deps().d);
  assertEquals([bad.status, bad.body.code], [400, 'INVALID_REQUEST']);
});
