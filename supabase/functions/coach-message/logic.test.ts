// T070 — coach-message decisions (contracts/backend-api.md `POST /coach-message`,
// contracts/ai-services.md §2). Written before logic.ts (T073).
import { assert, assertEquals, assertFalse } from 'jsr:@std/assert@1';
import {
  CACHE_MIN_SIMILARITY,
  CACHE_TTL_DAYS,
  type CoachDeps,
  type CoachOutput,
  detectInjury,
  FREE_WEEKLY_LIMIT,
  handleCoachMessage,
  isoWeekOf,
  MAX_MESSAGE_CHARS,
  type ModelOutcome,
  PROMPT_VERSION,
} from './logic.ts';
import type { SubscriptionRow } from '../_shared/entitlement.ts';

const NOW = new Date('2026-11-11T10:00:00Z'); // Wednesday, 2026-W46
const WEEK = '2026-W46';

const proSub: SubscriptionRow = {
  tier: 'pro',
  is_trial: false,
  current_period_ends_at: '2026-12-11T00:00:00Z',
  trial_ends_at: null,
};
const expiredTrial: SubscriptionRow = {
  tier: 'pro',
  is_trial: true,
  current_period_ends_at: null,
  trial_ends_at: '2026-11-10T00:00:00Z',
};

const reply = (over: Partial<CoachOutput> = {}): ModelOutcome => ({
  kind: 'reply',
  output: { content: 'Keep your core braced.', cacheable: false, plan_change: null, ...over },
});

/** In-memory fakes that record every call. */
function fakeDeps(opts: {
  sub?: SubscriptionRow | null;
  used?: number;
  cached?: string | null;
  model?: ModelOutcome;
  /** Overrides the clock; quota is then read per week from [usedByWeek]. */
  now?: Date;
  usedByWeek?: Record<string, number>;
} = {}) {
  const calls = {
    embed: [] as string[],
    findCached: [] as Parameters<CoachDeps['findCached']>[0][],
    storeCache: [] as Parameters<CoachDeps['storeCache']>[0][],
    model: [] as Parameters<CoachDeps['callModel']>[0][],
    quotaIncrements: [] as string[],
  };
  let used = opts.used ?? 0;
  const deps: CoachDeps = {
    now: () => opts.now ?? NOW,
    getSubscription: () => Promise.resolve(opts.sub ?? null),
    getQuotaUsed: (_userId, week) => {
      if (opts.usedByWeek) return Promise.resolve(opts.usedByWeek[week] ?? 0);
      assertEquals(week, WEEK);
      return Promise.resolve(used);
    },
    incrementQuota: (_userId, week) => {
      calls.quotaIncrements.push(week);
      used += 1;
      return Promise.resolve(used);
    },
    embed: (text) => {
      calls.embed.push(text);
      return Promise.resolve([0.1, 0.2, 0.3]);
    },
    findCached: (query) => {
      calls.findCached.push(query);
      return Promise.resolve(opts.cached ?? null);
    },
    storeCache: (entry) => {
      calls.storeCache.push(entry);
      return Promise.resolve();
    },
    callModel: (request) => {
      calls.model.push(request);
      return Promise.resolve(opts.model ?? reply());
    },
  };
  return { deps, calls };
}

const ask = (message: string, language: 'en' | 'fr' = 'en') => ({ userId: 'user-1', message, language });

// ---------------------------------------------------------------------------
// Injury pre-filter
// ---------------------------------------------------------------------------

Deno.test('EN and FR pain/injury keywords are detected', () => {
  for (const m of ['My knee hurts on squats', 'Sharp PAIN in my lower back', 'I think I have a sprain', 'feeling dizzy']) {
    assert(detectInjury(m), m);
  }
  for (const m of ["J'ai une douleur au genou", 'je me suis fait mal au dos', 'Une blessure à l’épaule', 'vertige']) {
    assert(detectInjury(m), m);
  }
  for (const m of ['How many sets should I do?', 'Can I swap bench for push-ups?', 'Combien de séries ?', 'animal flow']) {
    assertFalse(detectInjury(m), m);
  }
});

Deno.test('an injury message sets injury_flag and bypasses the cache entirely', async () => {
  const { deps, calls } = fakeDeps({ cached: 'cached answer', model: reply({ cacheable: true }) });
  const result = await handleCoachMessage(ask("J'ai mal au genou quand je squatte", 'fr'), deps);

  assert(result.ok);
  assertEquals(calls.embed.length, 0);
  assertEquals(calls.findCached.length, 0);
  assertEquals(calls.storeCache.length, 0); // never cached, even when the model says cacheable
  assertEquals(calls.model[0].injuryFlag, true);
});

// ---------------------------------------------------------------------------
// Semantic cache
// ---------------------------------------------------------------------------

Deno.test('cache lookup filters by language, current prompt_version, similarity ≥ 0.92 and expiry', async () => {
  const { deps, calls } = fakeDeps();
  await handleCoachMessage(ask('Combien de séries pour progresser ?', 'fr'), deps);

  assertEquals(calls.findCached.length, 1);
  const q = calls.findCached[0];
  assertEquals(q.language, 'fr');
  assertEquals(q.promptVersion, PROMPT_VERSION);
  assertEquals(q.minSimilarity, CACHE_MIN_SIMILARITY);
  assertEquals(CACHE_MIN_SIMILARITY, 0.92);
  assertEquals(q.now, NOW);
  assertEquals(q.embedding, [0.1, 0.2, 0.3]);
  assertEquals(calls.model[0].injuryFlag, false);
});

Deno.test('a cache hit returns the cached reply with no plan change and no model call', async () => {
  const { deps, calls } = fakeDeps({ cached: 'Rest 2–3 minutes between heavy sets.' });
  const result = await handleCoachMessage(ask('How long should I rest?'), deps);

  assert(result.ok);
  assertEquals(result.content, 'Rest 2–3 minutes between heavy sets.');
  assertEquals(result.plan_change, null);
  assertEquals(result.from_cache, true);
  assertEquals(calls.model.length, 0);
});

Deno.test('a reply is cached only when cacheable = true and plan_change = null', async () => {
  const change = {
    type: 'exercise_swap' as const,
    plan_exercise_id: 'pe-1',
    session_id: null,
    week_number: null,
    target_duration_min: null,
    old_exercise_slug: 'barbell-back-squat',
    new_exercise_slug: 'leg-press',
    new_weight_kg: null,
    new_reps_min: null,
    new_reps_max: null,
    reason_en: 'Knee-friendly.',
    reason_fr: 'Sans contrainte pour le genou.',
  };
  const cases: [Partial<CoachOutput>, boolean][] = [
    [{ cacheable: true, plan_change: null }, true],
    [{ cacheable: false, plan_change: null }, false],
    [{ cacheable: true, plan_change: change }, false],
  ];
  for (const [output, stored] of cases) {
    const { deps, calls } = fakeDeps({ model: reply(output) });
    await handleCoachMessage(ask('What does RPE mean?'), deps);
    assertEquals(calls.storeCache.length, stored ? 1 : 0, JSON.stringify(output));
  }

  const { deps, calls } = fakeDeps({ model: reply({ cacheable: true }) });
  await handleCoachMessage(ask('What does RPE mean?', 'fr'), deps);
  const entry = calls.storeCache[0];
  assertEquals(entry.language, 'fr');
  assertEquals(entry.promptVersion, PROMPT_VERSION);
  assertEquals(entry.expiresAt.getTime(), NOW.getTime() + CACHE_TTL_DAYS * 86_400_000);
});

// ---------------------------------------------------------------------------
// Free quota (server-side, authoritative)
// ---------------------------------------------------------------------------

Deno.test("a free user's 4th question returns QUOTA_EXCEEDED (429) before any cache lookup or model call", async () => {
  const { deps, calls } = fakeDeps({ used: FREE_WEEKLY_LIMIT });
  const result = await handleCoachMessage(ask('One more question?'), deps);

  assertFalse(result.ok);
  assertEquals(result.code, 'QUOTA_EXCEEDED');
  assertEquals(result.status, 429);
  assertEquals(calls.embed.length + calls.findCached.length + calls.model.length, 0);
  assertEquals(calls.quotaIncrements.length, 0);
});

Deno.test('quota_remaining goes 2 → 1 → 0 across three answered questions, then 429', async () => {
  const { deps } = fakeDeps();
  const remaining: (number | null)[] = [];
  for (let i = 0; i < 3; i++) {
    const r = await handleCoachMessage(ask(`Question ${i}`), deps);
    assert(r.ok);
    remaining.push(r.quota_remaining);
  }
  assertEquals(remaining, [2, 1, 0]);
  const fourth = await handleCoachMessage(ask('Question 4'), deps);
  assertFalse(fourth.ok);
  assertEquals(fourth.code, 'QUOTA_EXCEEDED');
});

Deno.test('quota is counted only when a reply is returned (cache hits count, failures do not)', async () => {
  const hit = fakeDeps({ cached: 'cached' });
  await handleCoachMessage(ask('Hit'), hit.deps);
  assertEquals(hit.calls.quotaIncrements, [WEEK]);

  for (const outcome of [{ kind: 'refusal' }, { kind: 'error' }] as ModelOutcome[]) {
    const { deps, calls } = fakeDeps({ model: outcome });
    const r = await handleCoachMessage(ask('Fails'), deps);
    assertFalse(r.ok);
    assertEquals(calls.quotaIncrements.length, 0, outcome.kind);
  }
});

Deno.test('Pro users never receive QUOTA_EXCEEDED and their quota is not tracked', async () => {
  const { deps, calls } = fakeDeps({ sub: proSub, used: 50 });
  const result = await handleCoachMessage(ask('Anything'), deps);

  assert(result.ok);
  assertEquals(result.quota_remaining, null);
  assertEquals(calls.quotaIncrements.length, 0);
});

Deno.test('an expired trial is treated as free', async () => {
  const { deps } = fakeDeps({ sub: expiredTrial, used: FREE_WEEKLY_LIMIT });
  const result = await handleCoachMessage(ask('Still Pro?'), deps);
  assertFalse(result.ok);
  assertEquals(result.code, 'QUOTA_EXCEEDED');
});

// ---------------------------------------------------------------------------
// Model failures and input limits
// ---------------------------------------------------------------------------

Deno.test('a refusal or model error returns AI_UNAVAILABLE (503)', async () => {
  for (const outcome of [{ kind: 'refusal' }, { kind: 'error' }] as ModelOutcome[]) {
    const { deps } = fakeDeps({ model: outcome });
    const result = await handleCoachMessage(ask('Explain progressive overload'), deps);
    assertFalse(result.ok);
    assertEquals(result.code, 'AI_UNAVAILABLE');
    assertEquals(result.status, 503);
  }
});

Deno.test('a message over 2000 characters returns MESSAGE_TOO_LONG (400) and costs nothing', async () => {
  const { deps, calls } = fakeDeps();
  const result = await handleCoachMessage(ask('x'.repeat(MAX_MESSAGE_CHARS + 1)), deps);
  assertFalse(result.ok);
  assertEquals(result.code, 'MESSAGE_TOO_LONG');
  assertEquals(result.status, 400);
  assertEquals(calls.model.length + calls.quotaIncrements.length, 0);
});

Deno.test('the model is asked to reply in the user language', async () => {
  const { deps, calls } = fakeDeps();
  await handleCoachMessage(ask('Pourquoi ce exercice ?', 'fr'), deps);
  assertEquals(calls.model[0].language, 'fr');
});

// ---------------------------------------------------------------------------
// Streaming (contracts/backend-api.md: text events, then done)
// ---------------------------------------------------------------------------

Deno.test('model text is forwarded to onText as it streams', async () => {
  const { deps } = fakeDeps();
  deps.callModel = (request) => {
    request.onText?.('Keep ');
    request.onText?.('bracing.');
    return Promise.resolve(reply({ content: 'Keep bracing.' }));
  };
  const seen: string[] = [];
  const result = await handleCoachMessage({ ...ask('Tips?'), onText: (t) => seen.push(t) }, deps);
  assert(result.ok);
  assertEquals(seen, ['Keep ', 'bracing.']);
});

Deno.test('a cache hit is sent through onText in one piece', async () => {
  const { deps } = fakeDeps({ cached: 'Rest 2 minutes.' });
  const seen: string[] = [];
  await handleCoachMessage({ ...ask('Rest?'), onText: (t) => seen.push(t) }, deps);
  assertEquals(seen, ['Rest 2 minutes.']);
});

Deno.test('nothing is sent through onText when the quota is exceeded', async () => {
  const { deps } = fakeDeps({ used: FREE_WEEKLY_LIMIT, cached: 'cached' });
  const seen: string[] = [];
  await handleCoachMessage({ ...ask('Q'), onText: (t) => seen.push(t) }, deps);
  assertEquals(seen, []);
});

Deno.test('a stored cache entry carries the question for its hash', async () => {
  const { deps, calls } = fakeDeps({ model: reply({ cacheable: true }) });
  await handleCoachMessage(ask('  What does RPE mean?  '), deps);
  assertEquals(calls.storeCache[0].question, 'What does RPE mean?');
});

Deno.test('isoWeekOf uses the user\'s time zone, not UTC (FR-020, T134)', () => {
  // Monday 00:30 in Paris is still Sunday 23:30 UTC: a new week for the user.
  assertEquals(isoWeekOf(new Date('2026-11-15T23:30:00Z'), 'Europe/Paris'), '2026-W47');
  // Monday 09:00 in Auckland (UTC+13) is Sunday 20:00 UTC.
  assertEquals(isoWeekOf(new Date('2026-11-15T20:00:00Z'), 'Pacific/Auckland'), '2026-W47');
  // Sunday 23:30 in New York is already Monday 04:30 UTC: still last week for the user.
  assertEquals(isoWeekOf(new Date('2026-11-16T04:30:00Z'), 'America/New_York'), WEEK);
  // An unknown zone falls back to UTC.
  assertEquals(isoWeekOf(new Date('2026-11-15T23:30:00Z'), 'Not/AZone'), WEEK);
});

Deno.test('the quota week is counted in the user\'s time zone (FR-020, T134)', async () => {
  // Paris, Monday 00:30 local: last week's 3 questions no longer count.
  const { deps, calls } = fakeDeps({ usedByWeek: { '2026-W46': 3 }, now: new Date('2026-11-15T23:30:00Z') });
  const result = await handleCoachMessage({ ...ask('What is a deload?'), timeZone: 'Europe/Paris' }, deps);
  assertEquals(result.ok, true);
  assertEquals(calls.quotaIncrements, ['2026-W47']);
  // The same instant for a UTC user is still the exhausted week.
  const utc = await handleCoachMessage({ ...ask('What is a deload?'), timeZone: 'UTC' }, deps);
  assertEquals(utc.ok ? null : utc.code, 'QUOTA_EXCEEDED');
});

Deno.test('isoWeekOf follows ISO 8601 (UTC)', () => {
  assertEquals(isoWeekOf(NOW), WEEK);
  assertEquals(isoWeekOf(new Date('2026-11-15T23:59:00Z')), WEEK); // Sunday
  assertEquals(isoWeekOf(new Date('2026-11-16T00:00:00Z')), '2026-W47'); // Monday
  assertEquals(isoWeekOf(new Date('2026-12-31T12:00:00Z')), '2026-W53');
  assertEquals(isoWeekOf(new Date('2024-12-30T12:00:00Z')), '2025-W01');
});
