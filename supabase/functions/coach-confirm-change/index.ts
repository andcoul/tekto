import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getAuthUser, errorResponse, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';

// ---------------------------------------------------------------------------
// Apply a coach-proposed plan change.
// ---------------------------------------------------------------------------
// Validates:
//   1. The message has a non-null plan_change_proposed
//   2. The replacement exercise has a video_front_url (Video Gate, Principle IV)
//   3. The plan_exercise belongs to the authenticated user's active plan
// Then applies the change and marks plan_change_applied = true.

serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { message_id: string };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON', 400);
  }

  if (!body.message_id) return errorResponse('message_id is required', 400);

  const db = getDb();

  // ---- Fetch the message ----
  const { data: message, error: msgErr } = await db
    .from('coach_messages')
    .select('id, plan_change_proposed, plan_change_applied, conversation_id')
    .eq('id', body.message_id)
    .single();

  if (msgErr || !message) return errorResponse('Message not found', 404);
  if (!message.plan_change_proposed) {
    return errorResponse('No plan_change_proposed on this message', 400);
  }
  if (message.plan_change_applied) {
    return errorResponse('Plan change already applied', 409);
  }

  const change = message.plan_change_proposed as {
    type: string;
    plan_exercise_id: string;
    new_exercise_slug: string;
  };

  if (change.type !== 'swap_exercise') {
    return errorResponse(`Unsupported change type: ${change.type}`, 400);
  }

  // ---- Video Gate: new exercise must have video_front_url ----
  const { data: exercise } = await db
    .from('exercises')
    .select('id, video_front_url')
    .eq('slug', change.new_exercise_slug)
    .single();

  if (!exercise) {
    return errorResponse('New exercise not found', 404);
  }
  if (!exercise.video_front_url) {
    return errorResponse('EXERCISE_NO_VIDEO: replacement exercise has no video', 400);
  }

  // ---- Verify ownership: plan_exercise must belong to user's active plan ----
  const { data: planExercise } = await db
    .from('plan_exercises')
    .select(`
      id,
      sessions!inner(plans!inner(user_id, status))
    `)
    .eq('id', change.plan_exercise_id)
    .single();

  if (!planExercise) return errorResponse('Plan exercise not found', 404);

  // deno-lint-ignore no-explicit-any
  const plan = (planExercise as any).sessions?.plans;
  if (plan?.user_id !== user.id) return errorResponse('Forbidden', 403);
  if (plan?.status !== 'active') return errorResponse('Plan is not active', 400);

  // ---- Apply the swap ----
  await db
    .from('plan_exercises')
    .update({ exercise_id: exercise.id })
    .eq('id', change.plan_exercise_id);

  // ---- Mark message as applied ----
  await db
    .from('coach_messages')
    .update({ plan_change_applied: true })
    .eq('id', body.message_id);

  return jsonResponse({
    applied: true,
    plan_exercise_id: change.plan_exercise_id,
    new_exercise_id: exercise.id,
  });
});
