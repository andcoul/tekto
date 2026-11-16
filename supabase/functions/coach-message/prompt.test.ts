// Coach prompt rules (contracts/ai-services.md §2, Constitution III).
import { assert, assertEquals, assertFalse, assertStringIncludes } from 'jsr:@std/assert@1';
import { type CoachContext, messagePrompt, REFERRAL_SENTENCE, stablePrompt } from './prompt.ts';

const ctx = (over: Partial<CoachContext> = {}): CoachContext => ({
  language: 'en',
  goal: 'strength',
  level: 'intermediate',
  equipment: ['barbell', 'dumbbell'],
  limitations: ['knee'],
  limitationsNote: 'old ACL surgery',
  currentWeek: 3,
  weeksTotal: 8,
  planSummary: { today: 'Lower A' },
  recentHistory: { workouts: 5 },
  allowedAlternatives: ['leg-press', 'goblet-squat'],
  ...over,
});

Deno.test('the stable prompt names the reply language and its referral sentence', () => {
  const fr = stablePrompt(ctx({ language: 'fr' }));
  assertStringIncludes(fr, 'Always reply in French');
  assertStringIncludes(fr, REFERRAL_SENTENCE.fr);
  assertFalse(fr.includes(REFERRAL_SENTENCE.en));
});

Deno.test('the stable prompt lists allowed alternatives, limitations and the cacheable rule', () => {
  const p = stablePrompt(ctx());
  assertStringIncludes(p, 'leg-press, goblet-squat');
  assertStringIncludes(p, 'Limitations: knee');
  assertStringIncludes(p, 'old ACL surgery');
  assertStringIncludes(p, '"cacheable" to true ONLY');
  assertStringIncludes(p, 'Current week: 3 of 8');
});

Deno.test('the stable prompt does not depend on the message (so it can be cached)', () => {
  assertEquals(stablePrompt(ctx()), stablePrompt(ctx()));
});

Deno.test('the message prompt adds the safety instruction only for injury messages', () => {
  assertEquals(messagePrompt(ctx(), { injuryFlag: false, screen: null, exerciseName: null }), '');
  const p = messagePrompt(ctx({ language: 'fr' }), { injuryFlag: true, screen: null, exerciseName: null });
  assertStringIncludes(p, REFERRAL_SENTENCE.fr);
  assertStringIncludes(p, 'cacheable to false');
});

Deno.test('the message prompt carries the screen and exercise being viewed', () => {
  const p = messagePrompt(ctx(), { injuryFlag: false, screen: 'exercise_detail', exerciseName: 'Romanian deadlift' });
  assert(p.startsWith('SCREEN CONTEXT: exercise_detail — viewing exercise: Romanian deadlift'));
});
