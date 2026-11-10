import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { getAuthUser, errorResponse, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';

// ---------------------------------------------------------------------------
// GDPR account deletion — FR-037, FR-038
// ---------------------------------------------------------------------------
// DELETE body: { "confirm": true }
//
// Steps:
//   1. Delete RevenueCat customer record
//   2. Delete auth.users row (cascades to all user data via ON DELETE CASCADE)

serve(async (req: Request) => {
  if (req.method !== 'DELETE') return errorResponse('Method not allowed', 405);

  const user = await getAuthUser(req);
  if (!user) return errorResponse('Unauthorized', 401);

  let body: { confirm: boolean };
  try {
    body = await req.json();
  } catch {
    return errorResponse('Invalid JSON', 400);
  }

  if (body.confirm !== true) {
    return errorResponse('Explicit { "confirm": true } body required', 400);
  }

  const db = getDb();

  // ---- Delete RevenueCat customer ----
  try {
    const revenueCatProjectId = Deno.env.get('REVENUECAT_PROJECT_ID');
    const revenueCatSecretKey = Deno.env.get('REVENUECAT_SECRET_KEY');

    if (revenueCatProjectId && revenueCatSecretKey) {
      const rcResp = await fetch(
        `https://api.revenuecat.com/v2/projects/${revenueCatProjectId}/customers/${user.id}`,
        {
          method: 'DELETE',
          headers: { Authorization: `Bearer ${revenueCatSecretKey}` },
        },
      );
      if (!rcResp.ok) {
        console.warn(`RevenueCat delete returned ${rcResp.status} for user ${user.id}`);
      }
    }
  } catch (e) {
    console.warn('RevenueCat delete failed (non-fatal):', e);
    // Non-fatal: proceed with Supabase deletion
  }

  // ---- Delete from auth.users (cascades to all user data) ----
  const { error } = await db.auth.admin.deleteUser(user.id);
  if (error) {
    console.error('Failed to delete user:', error);
    return errorResponse('Failed to delete account', 500);
  }

  return jsonResponse({ deleted: true });
});
