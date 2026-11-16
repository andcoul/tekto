import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, getAuthUser, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { buildSwapDeps } from '../swap-exercise/deps.ts';
import { type ConfirmDeps, type ConfirmRequest, handleConfirm, type PlanExerciseRow } from './apply.ts';

// POST /coach-confirm-change — contracts/backend-api.md §3 (FR-018). Rules live in apply.ts:
// all four change types, checked against the user's active plan; swaps follow the user-swap
// rules (Video Gate, equipment, limitations — Constitution IV); `confirmed: false` records
// the rejection. plan_exercises reference exercises by `exercise_slug` (001_initial_schema.sql).
serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthUser(req);
  if (!user) return errorResponse('Unauthorized', 401, 'UNAUTHORIZED');

  let body: ConfirmRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON', 400, 'INVALID_REQUEST');
  }

  const db = getDb();
  const throwOn = (error: { message: string } | null) => {
    if (error) throw new Error(error.message);
  };

  const deps: ConfirmDeps = {
    now: () => new Date(),
    loadMessage: async (id) => {
      const { data } = await db
        .from('coach_messages')
        .select('id, plan_change_proposed, plan_change_applied, plan_change_rejected_at, coach_conversations!inner(user_id)')
        .eq('id', id)
        .maybeSingle();
      if (!data) return null;
      return {
        id: data.id,
        // deno-lint-ignore no-explicit-any -- nested select shape
        user_id: (data as any).coach_conversations?.user_id,
        plan_change_proposed: data.plan_change_proposed,
        plan_change_applied: data.plan_change_applied,
        plan_change_rejected_at: data.plan_change_rejected_at,
      };
    },
    loadActivePlanExercises: async (userId) => {
      const { data, error } = await db
        .from('plan_exercises')
        .select(
          'id, session_id, exercise_slug, sort_order, sets, reps_min, reps_max, rest_sec, suggested_weight_kg, ' +
            'sessions!inner(week_number, plans!inner(user_id, status))',
        )
        .eq('sessions.plans.user_id', userId)
        .eq('sessions.plans.status', 'active');
      throwOn(error);
      // deno-lint-ignore no-explicit-any -- nested select shape
      return (data ?? []).map((r: any): PlanExerciseRow => ({
        id: r.id,
        session_id: r.session_id,
        week_number: r.sessions.week_number,
        exercise_slug: r.exercise_slug,
        sort_order: r.sort_order,
        sets: r.sets,
        reps_min: r.reps_min,
        reps_max: r.reps_max,
        rest_sec: r.rest_sec,
        suggested_weight_kg: r.suggested_weight_kg === null ? null : Number(r.suggested_weight_kg),
      }));
    },
    updatePlanExercise: async (id, patch) => {
      const { error } = await db.from('plan_exercises').update(patch).eq('id', id);
      throwOn(error);
    },
    deletePlanExercises: async (ids) => {
      const { error } = await db.from('plan_exercises').delete().in('id', ids);
      throwOn(error);
    },
    updateSessionEstimate: async (sessionId, minutes) => {
      const { error } = await db.from('sessions').update({ estimated_min: minutes }).eq('id', sessionId);
      throwOn(error);
    },
    markApplied: async (messageId) => {
      const { error } = await db.from('coach_messages').update({ plan_change_applied: true }).eq('id', messageId);
      throwOn(error);
    },
    markRejected: async (messageId, at) => {
      const { error } = await db.from('coach_messages').update({ plan_change_rejected_at: at.toISOString() }).eq('id', messageId);
      throwOn(error);
    },
    swap: buildSwapDeps(db),
  };

  try {
    const result = await handleConfirm(user.id, body, deps);
    return jsonResponse(result.body, result.status);
  } catch (err) {
    return errorResponse(`Failed to apply the change: ${(err as Error).message}`, 500, 'APPLY_FAILED');
  }
});
