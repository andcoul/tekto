import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { requireAuth, errorResponse, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { getAnthropicClient, COACH_MODEL } from '../_shared/claude.ts';
import { computeAdaptation, WeekData } from '../_shared/plan-adaptation.ts';

// ---------------------------------------------------------------------------
// Adapt plan after a completed training week
// ---------------------------------------------------------------------------
// POST body: { plan_id: string, completed_week: number }
//
// Validates all sessions in completed_week have workout_logs.finished_at set.
// Calls PlanAdaptationService for each plan_exercise.
// For each AdaptationEvent, calls Claude Haiku to generate natural-language reasons.
// Updates plan_exercises.suggested_weight_kg or reps_max.
// Appends to plans.adaptation_log JSONB.

serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await requireAuth(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { plan_id: string; completed_week: number };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON', 400);
  }

  if (!body.plan_id || body.completed_week == null) {
    return errorResponse('plan_id and completed_week are required', 400);
  }

  const db = getDb();

  // ---- Verify plan ownership ----
  const { data: plan, error: planErr } = await db
    .from('plans')
    .select('id, user_id, weeks_total, adaptation_log')
    .eq('id', body.plan_id)
    .eq('user_id', user.id)
    .single();

  if (planErr || !plan) return errorResponse('Plan not found', 404);

  // ---- Verify Pro entitlement ----
  const { data: sub } = await db
    .from('subscriptions')
    .select('tier')
    .eq('user_id', user.id)
    .single();

  if (sub?.tier !== 'pro') return errorResponse('PRO_REQUIRED', 403);

  // ---- Load sessions for completed_week ----
  const { data: sessions } = await db
    .from('sessions')
    .select(`
      id, day_of_week,
      workout_logs!inner(id, finished_at),
      plan_exercises(
        id, reps_min, reps_max, rpe_target, suggested_weight_kg,
        exercises!inner(equipment)
      )
    `)
    .eq('plan_id', body.plan_id);

  if (!sessions?.length) {
    return errorResponse('No sessions found for this plan', 404);
  }

  // ---- Verify all sessions are complete ----
  const incompleteSessions = sessions.filter(
    // deno-lint-ignore no-explicit-any
    (s: any) => !s.workout_logs?.some((wl: any) => wl.finished_at),
  );
  if (incompleteSessions.length > 0) {
    return errorResponse('WEEK_NOT_COMPLETE', 400);
  }

  // ---- Build WeekData for each plan_exercise ----
  const weekDataList: WeekData[] = [];

  for (const session of sessions) {
    // deno-lint-ignore no-explicit-any
    for (const pe of (session as any).plan_exercises ?? []) {
      // deno-lint-ignore no-explicit-any
      const workoutLogIds = (session as any).workout_logs.map((wl: any) => wl.id);

      const { data: setLogs } = await db
        .from('set_logs')
        .select('id, plan_exercise_id, weight_kg, reps, rpe_actual, workout_log_id')
        .eq('plan_exercise_id', pe.id)
        .in('workout_log_id', workoutLogIds);

      weekDataList.push({
        planExercise: {
          id: pe.id,
          reps_min: pe.reps_min,
          reps_max: pe.reps_max,
          rpe_target: pe.rpe_target,
          suggested_weight_kg: pe.suggested_weight_kg,
          exercise_id: pe.exercise_id,
          // deno-lint-ignore no-explicit-any
          equipment: (pe as any).exercises?.equipment ?? 'barbell',
        },
        setLogs: setLogs ?? [],
        plannedSessionCount: sessions.length,
        completedSessionCount: sessions.length - incompleteSessions.length,
      });
    }
  }

  // ---- Compute adaptations ----
  const events = computeAdaptation(weekDataList);

  if (events.length === 0) {
    return jsonResponse({ adapted: false, events: [] });
  }

  // ---- Generate natural-language reasons via Claude Haiku ----
  const anthropic = getAnthropicClient();
  const enrichedEvents = await Promise.all(
    events.map(async (event) => {
      try {
        const response = await anthropic.messages.create({
          model: COACH_MODEL,
          max_tokens: 100,
          messages: [{
            role: 'user',
            content: `Generate a brief (1 sentence), encouraging reason for this training adaptation.
            Field changed: ${event.field}.
            Old: ${event.oldValue}, New: ${event.newValue}.
            Response as JSON: {"en": "...", "fr": "..."}`
          }],
        });
        const text = response.content[0].type === 'text' ? response.content[0].text : '';
        const parsed = JSON.parse(text);
        return {
          ...event,
          reasonEn: parsed.en ?? event.reasonEn,
          reasonFr: parsed.fr ?? event.reasonFr,
        };
      } catch {
        return event; // fall back to computed reason
      }
    }),
  );

  // ---- Apply updates ----
  for (const event of enrichedEvents) {
    await db
      .from('plan_exercises')
      .update({ [event.field]: event.newValue })
      .eq('id', event.planExerciseId);
  }

  // ---- Append adaptation log ----
  const adaptationEntry = {
    week: body.completed_week,
    adapted_at: new Date().toISOString(),
    events: enrichedEvents.map((e) => ({
      planExerciseId: e.planExerciseId,
      field: e.field,
      oldValue: e.oldValue,
      newValue: e.newValue,
    })),
  };

  const currentLog = Array.isArray(plan.adaptation_log) ? plan.adaptation_log : [];
  await db
    .from('plans')
    .update({ adaptation_log: [...currentLog, adaptationEntry] })
    .eq('id', body.plan_id);

  return jsonResponse({
    adapted: true,
    events: enrichedEvents,
  });
});
