import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { COACH_MODEL, getAnthropicClient } from '../_shared/claude.ts';
import { getDb } from '../_shared/db.ts';
import { HealthProbe } from './probe.ts';

// GET /health — contracts/backend-api.md §9 (SC-013). No auth, no user data; polled every
// minute by the external uptime monitor (T092). Deploy with --no-verify-jwt.
const probe = new HealthProbe({
  now: () => Date.now(),
  checkDb: async () => {
    const { error } = await getDb().from('exercises').select('slug', { head: true, count: 'exact' }).limit(1);
    if (error) throw new Error(error.message);
  },
  // Reachability and key validity through the Models API: no tokens are generated.
  checkAi: async () => {
    await getAnthropicClient().models.retrieve(COACH_MODEL, {}, { timeout: 5_000 });
  },
});

serve(async (req: Request) => {
  if (req.method !== 'GET') return new Response('Method not allowed', { status: 405 });
  const result = await probe.check();
  return new Response(JSON.stringify(result.body), {
    status: result.status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
});
