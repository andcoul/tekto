// Supabase wiring for the swap rules in handler.ts; shared by swap-exercise and
// coach-confirm-change (a coach `exercise_swap` follows the same rules — FR-018, FR-028).
import type { SwapDeps } from './handler.ts';

// deno-lint-ignore no-explicit-any -- supabase-js client
export function buildSwapDeps(db: any): SwapDeps {
  return {
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
        .select('id, exercise_slug, sessions!inner(plans!inner(user_id, status))')
        .eq('id', id)
        .maybeSingle();
      if (!data) return null;
      // deno-lint-ignore no-explicit-any -- nested select shape
      const plan = (data as any).sessions?.plans;
      return { id: data.id, exercise_slug: data.exercise_slug, user_id: plan?.user_id, plan_status: plan?.status };
    },
    loadProfile: async (userId) => {
      const [{ data: profile }, { data: sub }] = await Promise.all([
        db.from('users').select('equipment, limitations').eq('id', userId).single(),
        db.from('subscriptions').select('tier').eq('user_id', userId).maybeSingle(),
      ]);
      return {
        equipment: profile?.equipment ?? [],
        limitations: profile?.limitations ?? [],
        tier: sub?.tier ?? 'free',
      };
    },
    applySwap: async (planExerciseId, newExerciseSlug) => {
      const { error } = await db.from('plan_exercises').update({ exercise_slug: newExerciseSlug }).eq(
        'id',
        planExerciseId,
      );
      if (error) throw new Error(error.message);
    },
  };
}
