// Builds the video-download-urls response (contracts/backend-api.md §5). Pure apart from `sign`.

export interface DownloadableExercise {
  slug: string;
  video_front_url: string | null;
  video_side_url: string | null;
  captions_en_url: string;
  captions_fr_url: string;
}

export interface PlanDownload {
  exercise_slug: string;
  download_url_front: string;
  download_url_side: string | null;
  captions: { en: string; fr: string };
  expires_at: string;
}

/** Signs a Cloudflare Stream video id into a time-limited MP4 download URL. */
export type Signer = (videoId: string) => Promise<string>;

/** `https://customer-*.cloudflarestream.com/<videoId>/manifest/video.m3u8` → `<videoId>`. */
export function extractStreamVideoId(hlsUrl: string): string | null {
  return hlsUrl.match(/cloudflarestream\.com\/([a-z0-9]+)\//i)?.[1] ?? null;
}

/**
 * One entry per exercise with a signable front video. The side video is optional. An exercise
 * whose signing fails is skipped (logged) so one bad asset never blocks the whole plan.
 * Caption tracks are returned as stored: they are the public WebVTT tracks of the Stream video.
 */
export async function buildDownloads(
  exercises: DownloadableExercise[],
  sign: Signer,
  expiresAt: string,
): Promise<PlanDownload[]> {
  const downloads: PlanDownload[] = [];
  for (const ex of exercises) {
    const frontId = ex.video_front_url ? extractStreamVideoId(ex.video_front_url) : null;
    if (!frontId) continue;
    const sideId = ex.video_side_url ? extractStreamVideoId(ex.video_side_url) : null;
    try {
      const [front, side] = await Promise.all([sign(frontId), sideId ? sign(sideId) : Promise.resolve(null)]);
      downloads.push({
        exercise_slug: ex.slug,
        download_url_front: front,
        download_url_side: side,
        captions: { en: ex.captions_en_url, fr: ex.captions_fr_url },
        expires_at: expiresAt,
      });
    } catch (err) {
      console.error(JSON.stringify({ event: 'video_sign_failed', exercise_slug: ex.slug, error: String(err) }));
    }
  }
  return downloads;
}
