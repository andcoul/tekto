import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, getAuthUser, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { handleDelete } from './handler.ts';

// DELETE /delete-account — contracts/backend-api.md §8 (FR-037, Constitution II).
// Body { "confirm": true }. Steps and failure rules are in handler.ts.
serve(async (req: Request) => {
  if (req.method !== 'DELETE') return errorResponse('Method not allowed', 405);

  const user = await getAuthUser(req);
  if (!user) return errorResponse('Unauthorized', 401, 'UNAUTHORIZED');

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    body = null;
  }

  const db = getDb();
  const result = await handleDelete(user.id, body, {
    deleteRevenueCatCustomer: async (userId) => {
      const projectId = Deno.env.get('REVENUECAT_PROJECT_ID');
      const secretKey = Deno.env.get('REVENUECAT_SECRET_KEY');
      if (!projectId || !secretKey) throw new Error('RevenueCat credentials not configured');
      const res = await fetch(`https://api.revenuecat.com/v2/projects/${projectId}/customers/${userId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${secretKey}` },
      });
      if (!res.ok && res.status !== 404) throw new Error(`RevenueCat ${res.status}`);
    },
    deleteExportFiles: async (userId) => {
      const { data: files, error } = await db.storage.from('exports').list(userId, { limit: 1000 });
      if (error) throw new Error(error.message);
      if (files?.length) {
        const { error: removeError } = await db.storage.from('exports').remove(files.map((f) => `${userId}/${f.name}`));
        if (removeError) throw new Error(removeError.message);
      }
    },
    deleteAuthUser: async (userId) => {
      const { error } = await db.auth.admin.deleteUser(userId); // cascades to public.users and every owned row
      if (error) throw new Error(error.message);
    },
  });
  return jsonResponse(result.body, result.status);
});
