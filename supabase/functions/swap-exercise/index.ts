import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, getAuthUser, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { handleSwap, type SwapDeps, type SwapRequest } from './handler.ts';

// POST /swap-exercise — contracts/backend-api.md §4. Rules live in handler.ts (FR-028,
// Constitution IV): every tier, no AI call, Video Gate and equipment/limitation checks.
serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthUser(req);
  if (!user) return errorResponse('Unauthorized', 401, 'UNAUTHORIZED');

  let body: SwapRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON', 400, 'INVALID_REQUEST');
  }

  const db = getDb();
  const deps: SwapDeps = {
    loadExercise: async (id) => {
      const { data } = await db
        .from('exercises')
        .select('id, slug, name_en, name_fr, video_front_url, equipment, muscle_primary, contraindications')
        .eq('id', id)
        .maybeSingle();
      return data;
    },
    loadExerciseBySlug: async (slug) => {
      const { data } = await db
        .from('exercises')
        .select('id, slug, name_en, name_fr, video_front_url, equipment, muscle_primary, contraindications')
        .eq('slug', slug)
        .maybeSingle();
      return data;
    },
    loadPlanExercise: async (id) => {
      const { data } = await db
        .from('plan_exercises')
        .select('id, exercise_id, sessions!inner(plans!inner(user_id, status))')
        .eq('id', id)
        .maybeSingle();
      if (!data) return null;
      // deno-lint-ignore no-explicit-any -- nested select shape
      const plan = (data as any).sessions?.plans;
      return { id: data.id, exercise_id: data.exercise_id, user_id: plan?.user_id, plan_status: plan?.status };
    },
    loadProfile: async (userId) => {
      const [{ data: profile }, { data: sub }] = await Promise.all([
        db.from('users').select('equipment, limitations').eq('id', userId).single(),
        db.from('subscriptions').select('tier').eq('user_id', userId).maybeSingle(),
      ]);
      return { equipment: profile?.equipment ?? [], limitations: profile?.limitations ?? [], tier: sub?.tier ?? 'free' };
    },
    applySwap: async (planExerciseId, newExerciseId) => {
      const { error } = await db.from('plan_exercises').update({ exercise_id: newExerciseId }).eq('id', planExerciseId);
      if (error) throw new Error(error.message);
    },
  };

  try {
    const result = await handleSwap(user.id, body, deps);
    return jsonResponse(result.body, result.status);
  } catch (err) {
    return errorResponse(`Failed to swap exercise: ${(err as Error).message}`, 500, 'SWAP_FAILED');
  }
});
