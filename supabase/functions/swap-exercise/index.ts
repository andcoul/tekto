import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getAuthUser, errorResponse, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';

// ---------------------------------------------------------------------------
// Swap an exercise in the user's active plan
// ---------------------------------------------------------------------------
// POST body: { plan_exercise_id: string, new_exercise_id: string }
//
// Video Gate (Principle IV): new exercise MUST have video_front_url.
// Ownership check: plan_exercise must belong to the user's active plan.

serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { plan_exercise_id: string; new_exercise_id: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON', 400);
  }

  if (!body.plan_exercise_id || !body.new_exercise_id) {
    return errorResponse('plan_exercise_id and new_exercise_id are required', 400);
  }

  const db = getDb();

  // ---- Video Gate: new exercise must have video_front_url ----
  const { data: newExercise } = await db
    .from('exercises')
    .select('id, slug, name_en, video_front_url')
    .eq('id', body.new_exercise_id)
    .single();

  if (!newExercise) return errorResponse('Exercise not found', 404);
  if (!newExercise.video_front_url) {
    return errorResponse('EXERCISE_NO_VIDEO: exercise has no video', 400);
  }

  // ---- Ownership check ----
  const { data: planExercise } = await db
    .from('plan_exercises')
    .select(`
      id, exercise_id,
      sessions!inner(
        plans!inner(id, user_id, status)
      )
    `)
    .eq('id', body.plan_exercise_id)
    .single();

  if (!planExercise) return errorResponse('Plan exercise not found', 404);

  // deno-lint-ignore no-explicit-any
  const plan = (planExercise as any).sessions?.plans;
  if (plan?.user_id !== user.id) return errorResponse('Forbidden', 403);
  if (plan?.status !== 'active') return errorResponse('Plan is not active', 400);

  // ---- Apply swap ----
  const { data: updated, error } = await db
    .from('plan_exercises')
    .update({ exercise_id: body.new_exercise_id })
    .eq('id', body.plan_exercise_id)
    .select(`
      id, sets, reps_min, reps_max, rest_sec, suggested_weight_kg, rpe_target,
      exercises!inner(id, slug, name_en, name_fr, video_front_url, muscle_primary)
    `)
    .single();

  if (error) return errorResponse('Failed to update exercise', 500);

  return jsonResponse(updated);
});
