import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { errorResponse, getAuthUser, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { buildExport } from './export.ts';

// POST /export-data — contracts/backend-api.md §7 (FR-037, FR-038, Constitution II).
// Synchronous: one JSON file of every user-owned table (export.ts), stored in the private
// `exports` bucket (migration 012) at <user_id>/<job_id>.json and signed for 1 hour.
const BUCKET = 'exports';
const URL_TTL_SEC = 3600;

serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405);

  const user = await getAuthUser(req);
  if (!user) return errorResponse('Unauthorized', 401, 'UNAUTHORIZED');

  const db = getDb();
  try {
    const data = await buildExport(user.id, {
      select: async (table, column, values) => {
        const { data, error } = await db.from(table).select('*').in(column, values);
        if (error) throw new Error(`${table}: ${error.message}`);
        return data ?? [];
      },
    });

    const jobId = crypto.randomUUID();
    const path = `${user.id}/${jobId}.json`;
    const exportedAt = new Date();
    const file = JSON.stringify({ exported_at: exportedAt.toISOString(), user_id: user.id, data }, null, 2);

    const { error: uploadError } = await db.storage
      .from(BUCKET)
      .upload(path, new Blob([file], { type: 'application/json' }), { contentType: 'application/json' });
    if (uploadError) throw new Error(`upload: ${uploadError.message}`);

    const { data: signed, error: signError } = await db.storage.from(BUCKET).createSignedUrl(path, URL_TTL_SEC);
    if (signError || !signed) throw new Error(`sign: ${signError?.message}`);

    return jsonResponse({
      job_id: jobId,
      download_url: signed.signedUrl,
      expires_at: new Date(exportedAt.getTime() + URL_TTL_SEC * 1000).toISOString(),
    });
  } catch (err) {
    console.error(JSON.stringify({ event: 'export_failed', error: String(err) }));
    return errorResponse('Failed to generate export', 500, 'EXPORT_FAILED');
  }
});
