import { requireAuth, errorResponse, jsonResponse } from '../_shared/auth.ts';
import { getDb } from '../_shared/db.ts';

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

  const isPro = isProSubscription(sub);
  if (!isPro) {
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

  // 5. Fetch exercise video URLs
  const { data: exercises } = await db
    .from('exercises')
    .select('slug, video_front_url')
    .in('slug', slugs);

  if (!exercises) {
    return errorResponse('Failed to fetch exercise data.', 500);
  }

  // 6. Generate signed Cloudflare Stream download URLs (24-hour expiry)
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
  const downloads: Array<{ exercise_slug: string; signed_url: string; expires_at: string }> = [];

  for (const exercise of exercises) {
    if (!exercise.video_front_url) continue;

    // For Cloudflare Stream: request a signed download URL
    // The video ID is extracted from the HLS manifest URL
    const videoId = extractCloudflareVideoId(exercise.video_front_url);
    if (!videoId) continue;

    try {
      const signedUrl = await getCloudflareSignedUrl(videoId, CF_ACCOUNT_ID, CF_API_TOKEN);
      downloads.push({
        exercise_slug: exercise.slug,
        signed_url: signedUrl,
        expires_at: expiresAt,
      });
    } catch {
      // Skip exercises where signing fails; don't block the whole request
      console.error(`Failed to sign URL for exercise: ${exercise.slug}`);
    }
  }

  return jsonResponse({ downloads });
});

function isProSubscription(sub: any): boolean {
  if (!sub || sub.tier !== 'pro') return false;
  const now = Date.now();
  if (sub.is_trial && sub.trial_ends_at) {
    return new Date(sub.trial_ends_at).getTime() > now;
  }
  if (sub.current_period_ends_at) {
    return new Date(sub.current_period_ends_at).getTime() > now;
  }
  return false;
}

function extractCloudflareVideoId(hlsUrl: string): string | null {
  // HLS URL pattern: https://customer-*.cloudflarestream.com/<videoId>/manifest/video.m3u8
  const match = hlsUrl.match(/cloudflarestream\.com\/([a-f0-9]+)\//);
  return match?.[1] ?? null;
}

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
