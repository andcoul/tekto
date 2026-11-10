import { requireAuth, errorResponse, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';
import { isPro } from '../_shared/entitlement.ts';
import { buildDownloads, type DownloadableExercise } from './downloads.ts';

const CF_ACCOUNT_ID = Deno.env.get('CLOUDFLARE_ACCOUNT_ID')!;
const CF_API_TOKEN = Deno.env.get('CLOUDFLARE_STREAM_API_TOKEN')!;

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return errorResponse('Method not allowed', 405);
  }

  let userId: string;
  try {
    userId = await requireAuth(req);
  } catch (e: any) {
    return errorResponse(e.message, e.statusCode ?? 401, 'UNAUTHORIZED');
  }

  const db = getDb();

  // 1. Verify Pro subscription
  const { data: sub } = await db
    .from('subscriptions')
    .select('tier, is_trial, trial_ends_at, current_period_ends_at')
    .eq('user_id', userId)
    .maybeSingle();

  if (!isPro(sub)) {
    return errorResponse(
      'Pro subscription required for offline video downloads.',
      403,
      'PRO_REQUIRED',
    );
  }

  // 2. Parse request body
  let planId: string;
  try {
    const body = await req.json();
    planId = body.plan_id;
    if (!planId) throw new Error('Missing plan_id');
  } catch {
    return errorResponse('Invalid request body. Expected { plan_id: string }', 400);
  }

  // 3. Verify plan belongs to user
  const { data: plan } = await db
    .from('plans')
    .select('id')
    .eq('id', planId)
    .eq('user_id', userId)
    .maybeSingle();

  if (!plan) {
    return errorResponse('Plan not found or access denied.', 404, 'NOT_FOUND');
  }

  // 4. Fetch all exercise slugs in the plan (via sessions → plan_exercises → exercises)
  const { data: planExercises } = await db
    .from('plan_exercises')
    .select('exercise_slug, sessions!inner(plan_id)')
    .eq('sessions.plan_id', planId);

  if (!planExercises || planExercises.length === 0) {
    return jsonResponse({ downloads: [] });
  }

  const slugs = [...new Set(planExercises.map((pe: any) => pe.exercise_slug as string))];

  // 5. Fetch exercise video + caption URLs
  const { data: exercises } = await db
    .from('exercises')
    .select('slug, video_front_url, video_side_url, captions_en_url, captions_fr_url')
    .in('slug', slugs);

  if (!exercises) {
    return errorResponse('Failed to fetch exercise data.', 500);
  }

  // 6. Signed Cloudflare Stream MP4 download URLs (24-hour expiry)
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const downloads = await buildDownloads(
    exercises as DownloadableExercise[],
    (videoId) => getCloudflareSignedUrl(videoId, CF_ACCOUNT_ID, CF_API_TOKEN),
    expiresAt,
  );

  return jsonResponse({ downloads });
});

async function getCloudflareSignedUrl(
  videoId: string,
  accountId: string,
  apiToken: string,
): Promise<string> {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/${videoId}/downloads`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
    },
  );

  if (!response.ok) {
    throw new Error(`Cloudflare API error: ${response.status}`);
  }

  const data = await response.json() as any;
  return data.result?.url ?? data.result?.default?.url;
}
