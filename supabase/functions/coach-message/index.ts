// POST /coach-message — contracts/backend-api.md §3, ai-services.md §2 (T073).
// Decisions (quota, injury pre-filter, semantic cache, model outcome) live in logic.ts; this
// file loads context, wires Supabase/Claude/embeddings, persists messages and streams the reply
// as server-sent events. Errors known before any text (429, 400, 404, early 503) are plain JSON.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { z } from 'npm:zod@4.6.7';
import { errorResponse, getAuthUser } from '../_shared/auth.ts';
import { CACHE_CONTROL, callStructured, ClaudeUnavailableError, COACH_MODEL } from '../_shared/claude.ts';
import { getDb } from '../_shared/db.ts';
import { embed, EmbeddingUnavailableError } from '../_shared/embeddings.ts';
import { isAllowed } from '../_shared/exercise-substitution.ts';
import { JsonFieldStream } from '../_shared/json-content-stream.ts';
import type { PlanProfile } from '../_shared/plan-draft.ts';
import { loadLibrary } from '../_shared/plan-validator.ts';
import type { AppLanguage, LimitationTag } from '../_shared/types.ts';
import { type CoachDeps, type CoachOutput, type CoachResult, handleCoachMessage, MAX_MESSAGE_CHARS } from './logic.ts';
import { type CoachContext, messagePrompt, stablePrompt } from './prompt.ts';

const MODEL_TIMEOUT_MS = 20_000;
const HISTORY_TURNS = 10;
const MAX_ALTERNATIVES = 80;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const PlanChangeSchema = z.object({
  type: z.enum(['exercise_swap', 'session_shorten', 'deload', 'weight_adjustment']),
  plan_exercise_id: z.string().nullable(),
  session_id: z.string().nullable(),
  week_number: z.number().int().nullable(),
  target_duration_min: z.number().int().nullable(),
  old_exercise_slug: z.string().nullable(),
  new_exercise_slug: z.string().nullable(),
  new_weight_kg: z.number().nullable(),
  new_reps_min: z.number().int().nullable(),
  new_reps_max: z.number().int().nullable(),
  reason_en: z.string(),
  reason_fr: z.string(),
});
// `content` first so it streams before the other fields.
const CoachOutputSchema = z.object({
  content: z.string(),
  cacheable: z.boolean(),
  plan_change: PlanChangeSchema.nullable(),
});

interface CoachRequest {
  conversation_id?: string;
  message?: string;
  context?: { screen?: string; exercise_slug?: string; session_id?: string };
}

serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthUser(req);
  if (!user) return errorResponse('UNAUTHORIZED', 401, 'UNAUTHORIZED');

  let body: CoachRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse('INVALID_REQUEST', 400, 'INVALID_REQUEST');
  }
  const message = body.message?.trim() ?? '';
  if (!message || !body.conversation_id || !UUID.test(body.conversation_id)) {
    return errorResponse('INVALID_REQUEST', 400, 'INVALID_REQUEST');
  }
  if (message.length > MAX_MESSAGE_CHARS) return errorResponse('MESSAGE_TOO_LONG', 400, 'MESSAGE_TOO_LONG');

  const db = getDb();
  const conversationId = body.conversation_id;

  // The app creates conversations offline; create the row on first use, refuse someone else's.
  const { data: convo } = await db.from('coach_conversations').select('user_id').eq('id', conversationId).maybeSingle();
  if (convo && convo.user_id !== user.id) return errorResponse('CONVERSATION_NOT_FOUND', 404, 'CONVERSATION_NOT_FOUND');

  const ctx = await loadContext(db, user.id);
  if (!ctx) return errorResponse('PROFILE_INCOMPLETE', 400, 'PROFILE_INCOMPLETE');
  if (!convo) {
    await db.from('coach_conversations').insert({ id: conversationId, user_id: user.id, plan_id: ctx.planId });
  }

  const history = await loadHistory(db, conversationId);
  const exerciseName = await exerciseNameFor(db, body.context?.exercise_slug, ctx.coach.language);

  // ---- Stream: text events as soon as the model (or cache) produces text ----
  const encoder = new TextEncoder();
  let controller!: ReadableStreamDefaultController<Uint8Array>;
  const stream = new ReadableStream<Uint8Array>({ start: (c) => void (controller = c) });
  const send = (event: string, data: unknown) =>
    controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));

  let started!: () => void;
  const firstText = new Promise<'text'>((resolve) => (started = () => resolve('text')));
  const onText = (text: string) => {
    if (!text) return;
    started();
    send('text', { text });
  };

  const deps = buildDeps(db, ctx.coach, history, body.context?.screen ?? null, exerciseName);
  const resultPromise = handleCoachMessage({ userId: user.id, message, language: ctx.coach.language, timeZone: ctx.timeZone, onText }, deps)
    .catch((err): CoachResult => {
      console.error(JSON.stringify({ event: 'coach_message_failed', error: String(err) }));
      return { ok: false, code: 'AI_UNAVAILABLE', status: 503 };
    });

  const first = await Promise.race([firstText, resultPromise.then(() => 'result' as const)]);

  if (first === 'result') {
    const result = await resultPromise;
    if (!result.ok) return errorResponse(result.code, result.status, result.code);
  }

  // Text has started (or a reply is ready): finish the stream in the background.
  void (async () => {
    const result = await resultPromise;
    try {
      if (result.ok) {
        const messageId = await persist(db, conversationId, message, body.context, result.content, result.plan_change);
        send('done', { message_id: messageId, plan_change_proposed: result.plan_change, quota_remaining: result.quota_remaining });
      } else {
        send('error', { error: result.code });
      }
    } catch (err) {
      console.error(JSON.stringify({ event: 'coach_persist_failed', error: String(err) }));
      send('error', { error: 'AI_UNAVAILABLE' });
    } finally {
      controller.close();
    }
  })();

  return new Response(stream, {
    status: 200,
    headers: { 'Content-Type': 'text/event-stream; charset=utf-8', 'Cache-Control': 'no-cache', Connection: 'keep-alive' },
  });
});

// ---------------------------------------------------------------------------
// Ports
// ---------------------------------------------------------------------------

function buildDeps(
  // deno-lint-ignore no-explicit-any -- supabase-js client type differs between esm.sh builds
  db: any,
  coach: CoachContext,
  history: { role: 'user' | 'assistant'; content: string }[],
  screen: string | null,
  exerciseName: string | null,
): CoachDeps {
  return {
    now: () => new Date(),
    getSubscription: async (userId) => {
      const { data } = await db
        .from('subscriptions')
        .select('tier, is_trial, trial_ends_at, current_period_ends_at')
        .eq('user_id', userId)
        .maybeSingle();
      return data;
    },
    getQuotaUsed: async (userId, isoWeek) => {
      const { data } = await db
        .from('coach_quota_usage')
        .select('questions_used')
        .eq('user_id', userId)
        .eq('iso_week', isoWeek)
        .maybeSingle();
      return data?.questions_used ?? 0;
    },
    incrementQuota: async (userId, isoWeek) => {
      const { data, error } = await db.rpc('increment_coach_quota', { p_user_id: userId, p_iso_week: isoWeek });
      if (error) throw new Error(error.message);
      return data as number;
    },
    // Embeddings are an optimisation: if the runtime cannot embed, skip the cache.
    embed: async (text) => {
      try {
        return await embed(text);
      } catch (err) {
        if (err instanceof EmbeddingUnavailableError) return [];
        throw err;
      }
    },
    findCached: async (q) => {
      if (q.embedding.length === 0) return null;
      const { data, error } = await db.rpc('match_coach_cache', {
        p_embedding: JSON.stringify(q.embedding),
        p_language: q.language,
        p_prompt_version: q.promptVersion,
        p_min_similarity: q.minSimilarity,
      });
      if (error) {
        console.error(JSON.stringify({ event: 'coach_cache_lookup_failed', error: error.message }));
        return null;
      }
      return (data as string | null) ?? null;
    },
    storeCache: async (entry) => {
      if (entry.embedding.length === 0) return;
      const { error } = await db.from('coach_response_cache').upsert({
        language: entry.language,
        embedding: JSON.stringify(entry.embedding),
        question_hash: await sha256(`${entry.language}:${entry.question.toLowerCase()}`),
        response_content: entry.content,
        prompt_version: entry.promptVersion,
        expires_at: entry.expiresAt.toISOString(),
      }, { onConflict: 'question_hash' });
      if (error) console.error(JSON.stringify({ event: 'coach_cache_store_failed', error: error.message }));
    },
    callModel: async ({ message, injuryFlag, onText }) => {
      const extractor = new JsonFieldStream('content');
      const perMessage = messagePrompt(coach, { injuryFlag, screen, exerciseName });
      try {
        const { output } = await callStructured<CoachOutput>({
          fn: 'coach-message',
          model: COACH_MODEL,
          system: [
            { type: 'text', text: stablePrompt(coach), cache_control: CACHE_CONTROL },
            ...(perMessage ? [{ type: 'text' as const, text: perMessage }] : []),
          ],
          messages: [
            ...history.map((m) => ({ role: m.role, content: m.content })),
            { role: 'user', content: message },
          ],
          schema: CoachOutputSchema as z.ZodType<CoachOutput>,
          effort: 'low',
          maxTokens: 800,
          timeoutMs: MODEL_TIMEOUT_MS,
          onText: (delta) => onText?.(extractor.push(delta)),
        });
        // An injury reply is never cacheable, whatever the model says.
        return { kind: 'reply', output: injuryFlag ? { ...output, cacheable: false } : output };
      } catch (err) {
        if (err instanceof ClaudeUnavailableError) return { kind: err.reason === 'refusal' ? 'refusal' : 'error' };
        throw err;
      }
    },
  };
}

// ---------------------------------------------------------------------------
// Context
// ---------------------------------------------------------------------------

// deno-lint-ignore no-explicit-any
async function loadContext(
  db: any,
  userId: string,
): Promise<{ coach: CoachContext; planId: string | null; timeZone: string } | null> {
  const { data: profile } = await db
    .from('users')
    .select('goal, level, language, equipment, limitations, limitations_note, days_per_week, session_length_min, timezone')
    .eq('id', userId)
    .maybeSingle();
  if (!profile) return null;

  const { data: plan } = await db
    .from('plans')
    .select('id, name, weeks_total, current_week')
    .eq('user_id', userId)
    .eq('status', 'active')
    .maybeSingle();

  let planSummary: unknown = null;
  if (plan) {
    const { data: sessions } = await db
      .from('sessions')
      .select('id, day_of_week, name_en, name_fr, plan_exercises(id, exercise_slug, sets, reps_min, reps_max, rpe_target, rir_target, suggested_weight_kg, sort_order)')
      .eq('plan_id', plan.id)
      .eq('week_number', plan.current_week)
      .order('day_of_week');
    planSummary = { name: plan.name, week: plan.current_week, sessions: sessions ?? [] };
  }

  const since = new Date(Date.now() - 14 * 86_400_000).toISOString();
  const [{ data: logs }, { data: prs }] = await Promise.all([
    db.from('workout_logs').select('started_at, finished_at, effort_rating, total_volume_kg').eq('user_id', userId)
      .gte('started_at', since).order('started_at', { ascending: false }).limit(14),
    db.from('personal_records').select('exercise_slug, best_weight_kg, best_reps, achieved_at').eq('user_id', userId)
      .gte('achieved_at', since).order('achieved_at', { ascending: false }).limit(10),
  ]);

  const limitations = (profile.limitations ?? []) as LimitationTag[];
  const planProfile = {
    level: profile.level,
    equipment: profile.equipment ?? [],
    limitations,
    session_length_min: profile.session_length_min,
    days_per_week: profile.days_per_week,
  } as PlanProfile;
  const library = await loadLibrary(db);
  const allowed = [...library.values()]
    .filter((ex) => ex.video_front_url && isAllowed(ex, planProfile))
    .map((ex) => ex.slug)
    .sort()
    .slice(0, MAX_ALTERNATIVES);

  return {
    planId: plan?.id ?? null,
    timeZone: profile.timezone ?? 'UTC', // quota week (FR-020)
    coach: {
      language: profile.language as AppLanguage,
      goal: profile.goal,
      level: profile.level,
      equipment: profile.equipment ?? [],
      limitations,
      limitationsNote: profile.limitations_note ?? null,
      currentWeek: plan?.current_week ?? null,
      weeksTotal: plan?.weeks_total ?? null,
      planSummary,
      recentHistory: { workouts: logs ?? [], personal_records: prs ?? [] },
      allowedAlternatives: allowed,
    },
  };
}

/** Last turns, oldest first. Assistant turns are replayed in the output format (ai-services §2). */
// deno-lint-ignore no-explicit-any
async function loadHistory(db: any, conversationId: string) {
  const { data } = await db
    .from('coach_messages')
    .select('role, content, plan_change_proposed')
    .eq('conversation_id', conversationId)
    .in('role', ['user', 'assistant'])
    .order('created_at', { ascending: false })
    .limit(HISTORY_TURNS * 2);
  return ((data ?? []) as { role: 'user' | 'assistant'; content: string; plan_change_proposed: unknown }[])
    .reverse()
    .map((m) => ({
      role: m.role,
      content: m.role === 'assistant' ? JSON.stringify({ content: m.content, plan_change: m.plan_change_proposed ?? null }) : m.content,
    }));
}

// deno-lint-ignore no-explicit-any
async function exerciseNameFor(db: any, slug: string | undefined, language: AppLanguage): Promise<string | null> {
  if (!slug) return null;
  const { data } = await db.from('exercises').select('name_en, name_fr').eq('slug', slug).maybeSingle();
  return data ? (language === 'fr' ? data.name_fr : data.name_en) : null;
}

/** Saves the question and the reply; returns the reply's id for the app (ratings, plan change). */
async function persist(
  // deno-lint-ignore no-explicit-any
  db: any,
  conversationId: string,
  message: string,
  context: CoachRequest['context'],
  content: string,
  planChange: unknown,
): Promise<string> {
  const { error: userErr } = await db.from('coach_messages').insert({
    conversation_id: conversationId,
    role: 'user',
    content: message,
    context_screen: context?.screen ?? null,
    context_exercise_slug: context?.exercise_slug ?? null,
  });
  if (userErr) throw new Error(userErr.message);
  const { data, error } = await db
    .from('coach_messages')
    .insert({ conversation_id: conversationId, role: 'assistant', content, plan_change_proposed: planChange })
    .select('id')
    .single();
  if (error) throw new Error(error.message);
  await db.from('coach_conversations').update({ updated_at: new Date().toISOString() }).eq('id', conversationId);
  return data.id as string;
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}
