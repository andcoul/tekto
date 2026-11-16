// coach-message decisions (T073): quota, injury pre-filter, semantic cache, model outcome.
// Pure orchestration over injected ports so every rule is unit-tested (logic.test.ts, T070).
// contracts/backend-api.md `POST /coach-message`, contracts/ai-services.md §2.
import { isPro, type SubscriptionRow } from '../_shared/entitlement.ts';
import type { AppLanguage, CoachPlanChange } from '../_shared/types.ts';
import { localDate } from '../_shared/week-boundary.ts';

/** Bumped whenever the system prompt or model changes; old cache rows stop matching. */
export const PROMPT_VERSION = 'coach-2026-11-16';
export const CACHE_MIN_SIMILARITY = 0.92;
export const CACHE_TTL_DAYS = 7;
export const FREE_WEEKLY_LIMIT = 3;
export const MAX_MESSAGE_CHARS = 2000;

/** Deterministic bilingual pre-filter (ai-services.md §2). Matched on whole words. */
const INJURY_KEYWORDS = [
  // EN
  'pain', 'painful', 'hurt', 'hurts', 'hurting', 'injury', 'injured', 'sprain', 'sprained', 'strain',
  'tear', 'torn', 'numb', 'numbness', 'tingling', 'swelling', 'swollen', 'dizzy', 'dizziness',
  'chest pain', 'faint', 'fainted',
  // FR
  'douleur', 'douleurs', 'douloureux', 'douloureuse', 'mal', 'blessure', 'blessé', 'blessée', 'entorse',
  'déchirure', 'engourdi', 'engourdie', 'engourdissement', 'fourmillements', 'vertige', 'vertiges',
  'gonflé', 'gonflée', 'malaise',
];

const keywordPattern = new RegExp(
  `(?<![\\p{L}])(?:${INJURY_KEYWORDS.map((k) => k.replace(/ /g, '\\s+')).join('|')})(?![\\p{L}])`,
  'iu',
);

export function detectInjury(message: string): boolean {
  return keywordPattern.test(message.normalize('NFC'));
}

/**
 * ISO 8601 week `YYYY-Www` of [date] as a calendar date in [timeZone] (week starts Monday;
 * week 1 holds January 4). The coach quota week is the user's own week (FR-020), so callers
 * pass `users.timezone`; an unknown zone falls back to UTC.
 */
export function isoWeekOf(date: Date, timeZone = 'UTC'): string {
  const [y, m, d] = localDate(date, timeZone).date.split('-').map(Number);
  const day = new Date(Date.UTC(y, m - 1, d));
  const weekday = (day.getUTCDay() + 6) % 7; // Monday = 0
  const thursday = new Date(day.getTime() + (3 - weekday) * 86_400_000);
  const year = thursday.getUTCFullYear();
  const jan4 = new Date(Date.UTC(year, 0, 4));
  const week1Monday = new Date(jan4.getTime() - ((jan4.getUTCDay() + 6) % 7) * 86_400_000);
  const week = Math.floor((thursday.getTime() - week1Monday.getTime()) / (7 * 86_400_000)) + 1;
  return `${year}-W${String(week).padStart(2, '0')}`;
}

// ---------------------------------------------------------------------------
// Ports
// ---------------------------------------------------------------------------

export interface CoachOutput {
  content: string;
  cacheable: boolean;
  plan_change: CoachPlanChange | null;
}

export type ModelOutcome =
  | { kind: 'reply'; output: CoachOutput }
  | { kind: 'refusal' }
  | { kind: 'error' };

export interface CoachDeps {
  now(): Date;
  getSubscription(userId: string): Promise<SubscriptionRow | null>;
  getQuotaUsed(userId: string, isoWeek: string): Promise<number>;
  /** Atomically adds one question; returns the new count. */
  incrementQuota(userId: string, isoWeek: string): Promise<number>;
  embed(text: string): Promise<number[]>;
  findCached(query: {
    embedding: number[];
    language: AppLanguage;
    promptVersion: string;
    minSimilarity: number;
    now: Date;
  }): Promise<string | null>;
  storeCache(entry: {
    question: string;
    embedding: number[];
    language: AppLanguage;
    promptVersion: string;
    content: string;
    expiresAt: Date;
  }): Promise<void>;
  callModel(request: {
    message: string;
    language: AppLanguage;
    injuryFlag: boolean;
    /** Receives the reply text as the model writes it. */
    onText?: (text: string) => void;
  }): Promise<ModelOutcome>;
}

export interface CoachInput {
  userId: string;
  message: string;
  language: AppLanguage;
  /** `users.timezone` (IANA); the quota week is counted in it. Defaults to UTC. */
  timeZone?: string;
  /** Receives the reply text as it becomes available (streamed to the app). */
  onText?: (text: string) => void;
}

export type CoachResult =
  | {
    ok: true;
    content: string;
    plan_change: CoachPlanChange | null;
    /** Free questions left this ISO week; null for Pro users. */
    quota_remaining: number | null;
    from_cache: boolean;
    injury_flag: boolean;
  }
  | { ok: false; code: 'QUOTA_EXCEEDED' | 'AI_UNAVAILABLE' | 'MESSAGE_TOO_LONG'; status: 400 | 429 | 503 };

// ---------------------------------------------------------------------------
// Flow
// ---------------------------------------------------------------------------

export async function handleCoachMessage(input: CoachInput, deps: CoachDeps): Promise<CoachResult> {
  if (input.message.length > MAX_MESSAGE_CHARS) return { ok: false, code: 'MESSAGE_TOO_LONG', status: 400 };

  const now = deps.now();
  const week = isoWeekOf(now, input.timeZone ?? 'UTC');

  // 1. Quota first, from the server's own subscription row (never the client's claim).
  const pro = isPro(await deps.getSubscription(input.userId), now);
  if (!pro && (await deps.getQuotaUsed(input.userId, week)) >= FREE_WEEKLY_LIMIT) {
    return { ok: false, code: 'QUOTA_EXCEEDED', status: 429 };
  }

  const injuryFlag = detectInjury(input.message);

  // 2. Semantic cache (skipped for injury messages, which must always reach the referral rule).
  let embedding: number[] | null = null;
  if (!injuryFlag) {
    embedding = await deps.embed(input.message);
    const cached = await deps.findCached({
      embedding,
      language: input.language,
      promptVersion: PROMPT_VERSION,
      minSimilarity: CACHE_MIN_SIMILARITY,
      now,
    });
    if (cached !== null) {
      input.onText?.(cached);
      return { ok: true, content: cached, plan_change: null, from_cache: true, injury_flag: false, ...await consume() };
    }
  }

  // 3. Model.
  const outcome = await deps.callModel({
    message: input.message,
    language: input.language,
    injuryFlag,
    onText: input.onText,
  });
  if (outcome.kind !== 'reply') return { ok: false, code: 'AI_UNAVAILABLE', status: 503 };
  const { content, cacheable, plan_change } = outcome.output;

  if (embedding !== null && cacheable && plan_change === null) {
    await deps.storeCache({
      question: input.message.trim(),
      embedding,
      language: input.language,
      promptVersion: PROMPT_VERSION,
      content,
      expiresAt: new Date(now.getTime() + CACHE_TTL_DAYS * 86_400_000),
    });
  }

  return { ok: true, content, plan_change, from_cache: false, injury_flag: injuryFlag, ...await consume() };

  /** Counts the answered question for free users (only reached when a reply is returned). */
  async function consume(): Promise<{ quota_remaining: number | null }> {
    if (pro) return { quota_remaining: null };
    const used = await deps.incrementQuota(input.userId, week);
    return { quota_remaining: Math.max(0, FREE_WEEKLY_LIMIT - used) };
  }
}
