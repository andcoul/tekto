import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { z } from 'npm:zod@4.6.7';
import { errorResponse, getAuthUser, jsonResponse } from '../_shared/auth.ts';
import { callStructured, COACH_MODEL } from '../_shared/claude.ts';
import { getDb } from '../_shared/db.ts';
import { isPro } from '../_shared/entitlement.ts';
import {
  type AdaptDeps,
  type AdaptPlan,
  type Explanation,
  handleBatch,
  handleUserMode,
  type WeekSnapshot,
} from './handler.ts';

// POST /adapt-plan — contracts/backend-api.md §2 (FR-026, FR-027; research §10).
//   User mode:  { plan_id, completed_week } with the user's JWT (early trigger from the app).
//   Batch mode: { mode: "batch" } with the service-role key (hourly pg_cron job, migration 006).
// Rules live in handler.ts; this file only wires Supabase and the explanation model.

const ExplanationSchema = z.object({
  reasons: z.array(z.object({ plan_exercise_id: z.string(), reason_en: z.string(), reason_fr: z.string() })),
  summary_en: z.string(),
  summary_fr: z.string(),
});

const PLAN_COLUMNS = 'id, user_id, start_date, current_week, weeks_total, last_adapted_week, adaptation_log, ' +
  'users!inner(timezone, subscriptions(tier, is_trial, trial_ends_at, current_period_ends_at))';

// deno-lint-ignore no-explicit-any -- nested select shape
function toPlan(row: any, now: Date): AdaptPlan {
  const subs = row.users?.subscriptions;
  const sub = Array.isArray(subs) ? subs[0] : subs;
  return {
    id: row.id,
    user_id: row.user_id,
    start_date: row.start_date,
    current_week: row.current_week,
    weeks_total: row.weeks_total,
    last_adapted_week: row.last_adapted_week,
    adaptation_log: Array.isArray(row.adaptation_log) ? row.adaptation_log : [],
    timezone: row.users?.timezone ?? 'UTC',
    pro: isPro(sub ?? null, now),
  };
}

function isServiceRole(req: Request): boolean {
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  return !!key && req.headers.get('Authorization') === `Bearer ${key}`;
}

serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  let body: { mode?: string; plan_id?: unknown; completed_week?: unknown };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON', 400, 'INVALID_REQUEST');
  }

  const db = getDb();
  const throwOn = (error: { message: string } | null) => {
    if (error) throw new Error(error.message);
  };

  const deps: AdaptDeps = {
    now: () => new Date(),
    loadPlan: async (planId) => {
      const { data, error } = await db.from('plans').select(PLAN_COLUMNS).eq('id', planId).eq('status', 'active').maybeSingle();
      throwOn(error);
      return data ? toPlan(data, new Date()) : null;
    },
    listActivePlans: async () => {
      const { data, error } = await db.from('plans').select(PLAN_COLUMNS).eq('status', 'active');
      throwOn(error);
      const now = new Date();
      return (data ?? []).map((r: unknown) => toPlan(r, now));
    },
    loadWeek: async (planId, week): Promise<WeekSnapshot> => {
      const { data: sessions, error } = await db
        .from('sessions')
        .select(
          'id, day_of_week, workout_logs(id, finished_at, effort_rating), ' +
            'plan_exercises(id, session_id, sort_order, exercise_slug, reps_min, reps_max, rpe_target, rir_target, ' +
            'suggested_weight_kg, exercises(equipment))',
        )
        .eq('plan_id', planId)
        .eq('week_number', week);
      throwOn(error);
      const snapshot: WeekSnapshot = { sessions: [], exercises: [], setLogs: [] };
      const finishedLogIds: string[] = [];
      // deno-lint-ignore no-explicit-any -- nested select shape
      for (const s of (sessions ?? []) as any[]) {
        // deno-lint-ignore no-explicit-any
        const finished = (s.workout_logs ?? []).filter((l: any) => l.finished_at)
          // deno-lint-ignore no-explicit-any
          .sort((a: any, b: any) => String(b.finished_at).localeCompare(String(a.finished_at)));
        finishedLogIds.push(...finished.map((l: { id: string }) => l.id));
        snapshot.sessions.push({
          id: s.id,
          day_of_week: s.day_of_week,
          finished: finished.length > 0,
          effort_rating: finished[0]?.effort_rating ?? null,
        });
        for (const pe of s.plan_exercises ?? []) {
          snapshot.exercises.push({
            id: pe.id,
            session_id: pe.session_id,
            sort_order: pe.sort_order,
            exercise_slug: pe.exercise_slug,
            equipment: pe.exercises?.equipment ?? [],
            reps_min: pe.reps_min,
            reps_max: pe.reps_max,
            rpe_target: pe.rpe_target === null ? null : Number(pe.rpe_target),
            rir_target: pe.rir_target ?? null,
            suggested_weight_kg: pe.suggested_weight_kg === null ? null : Number(pe.suggested_weight_kg),
          });
        }
      }
      if (finishedLogIds.length) {
        const { data: sets, error: setsError } = await db
          .from('set_logs')
          .select('id, plan_exercise_id, weight_kg, reps, rpe_actual, workout_log_id, logged_at')
          .in('workout_log_id', finishedLogIds)
          .order('logged_at', { ascending: true });
        throwOn(setsError);
        // deno-lint-ignore no-explicit-any
        snapshot.setLogs = (sets ?? []).map((r: any) => ({
          id: r.id,
          plan_exercise_id: r.plan_exercise_id,
          weight_kg: Number(r.weight_kg),
          reps: r.reps,
          rpe_actual: r.rpe_actual === null ? null : Number(r.rpe_actual),
          workout_log_id: r.workout_log_id,
        }));
      }
      return snapshot;
    },
    claimWeek: async (planId, week) => {
      const { data, error } = await db
        .from('plans')
        .update({ last_adapted_week: week })
        .eq('id', planId)
        .lt('last_adapted_week', week)
        .select('id');
      throwOn(error);
      return (data ?? []).length === 1;
    },
    setCurrentWeek: async (planId, week) => {
      const { error } = await db.from('plans').update({ current_week: week }).eq('id', planId).lt('current_week', week);
      throwOn(error);
    },
    applyUpdates: async (updates) => {
      for (const u of updates) {
        const { error } = await db.from('plan_exercises').update({ [u.field]: u.value }).eq('id', u.plan_exercise_id);
        throwOn(error);
      }
    },
    appendLog: async (planId, entry) => {
      // Safe read-modify-write: the week was claimed first, so only one writer reaches this.
      const { data, error } = await db.from('plans').select('adaptation_log').eq('id', planId).single();
      throwOn(error);
      const log = Array.isArray(data?.adaptation_log) ? data.adaptation_log : [];
      const { error: updateError } = await db.from('plans').update({ adaptation_log: [...log, entry] }).eq('id', planId);
      throwOn(updateError);
    },
    explain: async (input): Promise<Explanation> => {
      // ai-services §2b: the model only words the changes the service already decided.
      const { output } = await callStructured({
        fn: 'adapt-plan',
        model: COACH_MODEL,
        effort: 'low',
        maxTokens: 2048,
        timeoutMs: 20_000,
        schema: ExplanationSchema,
        system: [{
          type: 'text',
          text: 'You write short, encouraging explanations of weekly strength-plan changes for a training app, ' +
            'in English and in French. Do not change, add or drop any change; explain only the ones given. ' +
            'One sentence per change; a one- or two-sentence weekly summary that mentions sessions completed ' +
            'of scheduled. No medical advice. Keep each plan_exercise_id exactly as given.',
        }],
        messages: [{ role: 'user', content: JSON.stringify(input) }],
      });
      return output;
    },
  };

  try {
    if (body.mode === 'batch') {
      if (!isServiceRole(req)) return errorResponse('Batch mode requires the service role', 403, 'FORBIDDEN');
      const result = await handleBatch(deps);
      console.log(JSON.stringify({ event: 'adapt_batch', ...result.body }));
      return jsonResponse(result.body, result.status);
    }
    const user = await getAuthUser(req);
    if (!user) return errorResponse('Unauthorized', 401, 'UNAUTHORIZED');
    const result = await handleUserMode(user.id, body, deps);
    return jsonResponse(result.body, result.status);
  } catch (err) {
    return errorResponse(`Adaptation failed: ${(err as Error).message}`, 500, 'ADAPT_FAILED');
  }
});
