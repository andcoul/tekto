import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, getAuthUser, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { buildSwapDeps } from './deps.ts';
import { handleSwap, type SwapRequest } from './handler.ts';

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
  const deps = buildSwapDeps(db);

  try {
    const result = await handleSwap(user.id, body, deps);
    return jsonResponse(result.body, result.status);
  } catch (err) {
    return errorResponse(`Failed to swap exercise: ${(err as Error).message}`, 500, 'SWAP_FAILED');
  }
});
