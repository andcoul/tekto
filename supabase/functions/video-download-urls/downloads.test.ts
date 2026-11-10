// T027 — written before downloads.ts.
import { assertEquals } from 'jsr:@std/assert@1';
import { buildDownloads, extractStreamVideoId } from './downloads.ts';

const hls = (id: string) => `https://customer-abc.cloudflarestream.com/${id}/manifest/video.m3u8`;
const sign = (id: string) => Promise.resolve(`https://dl.test/${id}.mp4?token=t`);
const expiresAt = '2026-11-11T12:00:00.000Z';

Deno.test('extracts the Stream video id from an HLS URL', () => {
  assertEquals(extractStreamVideoId(hls('a1b2c3')), 'a1b2c3');
  assertEquals(extractStreamVideoId('https://example.com/video.m3u8'), null);
});

Deno.test('returns signed front + side downloads and both caption tracks', async () => {
  const out = await buildDownloads([{
    slug: 'barbell-squat',
    video_front_url: hls('f1'),
    video_side_url: hls('s1'),
    captions_en_url: 'https://cap.test/squat_en.vtt',
    captions_fr_url: 'https://cap.test/squat_fr.vtt',
  }], sign, expiresAt);
  assertEquals(out, [{
    exercise_slug: 'barbell-squat',
    download_url_front: 'https://dl.test/f1.mp4?token=t',
    download_url_side: 'https://dl.test/s1.mp4?token=t',
    captions: { en: 'https://cap.test/squat_en.vtt', fr: 'https://cap.test/squat_fr.vtt' },
    expires_at: expiresAt,
  }]);
});

Deno.test('side video is optional; exercises without a front video or with a failed signing are skipped', async () => {
  const failing = (id: string) => id === 'bad' ? Promise.reject(new Error('cf 500')) : sign(id);
  const out = await buildDownloads([
    { slug: 'push-up', video_front_url: hls('p1'), video_side_url: null, captions_en_url: 'e', captions_fr_url: 'f' },
    { slug: 'no-video', video_front_url: null, video_side_url: null, captions_en_url: 'e', captions_fr_url: 'f' },
    { slug: 'broken', video_front_url: hls('bad'), video_side_url: null, captions_en_url: 'e', captions_fr_url: 'f' },
  ], failing, expiresAt);
  assertEquals(out.map((d) => [d.exercise_slug, d.download_url_side]), [['push-up', null]]);
});
