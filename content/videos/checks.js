// Pure checks for the video loops (no I/O), so they can be tested without ffmpeg.

export const LIMITS = {
  aspect: 9 / 16, // width / height
  aspectTolerance: 0.03,
  minWidth: 720,
  minSec: 3.5,
  maxSec: 7,
  minFps: 24,
  loopPsnrDb: 25, // first vs last frame; below this the loop seam is likely visible
};

const baseName = (file) => file.replace(/^.*[\\/]/, '').replace(/\.[^.]+$/, '');

/**
 * Works out what a clip is for from its file name.
 * @param {string} file e.g. "legs-back-squat.mp4"
 * @param {{exercises: Record<string, string|null>, heroes: Record<string, string>}} map name-map.json
 * @param {Set<string>} librarySlugs slugs in content/exercises/exercises.json
 */
export function resolveTarget(file, map, librarySlugs) {
  const name = baseName(file);
  if (name in map.heroes) {
    return { name, kind: 'hero', slug: null, screen: map.heroes[name], problem: null };
  }
  if (name in map.exercises) {
    const slug = map.exercises[name];
    if (slug === null) {
      return {
        name, kind: 'exercise', slug: null,
        problem: `"${name}" is not in the exercise library yet. Add the exercise to exercises.json first (cues, captions, front video), then map it in name-map.json.`,
      };
    }
    if (!librarySlugs.has(slug)) {
      return { name, kind: 'exercise', slug, problem: `name-map.json points to "${slug}", which is missing from exercises.json.` };
    }
    return { name, kind: 'exercise', slug, problem: null };
  }
  const expected = [...Object.keys(map.exercises), ...Object.keys(map.heroes)].join(', ');
  return { name, kind: 'unknown', slug: null, problem: `Unknown file name "${name}". Use one of: ${expected}.` };
}

/**
 * Judges a probed clip. Errors block conversion; warnings are reported but the clip is still used.
 * @param {{width:number,height:number,durationSec:number,fps:number,loopPsnr:number|null}} c
 */
export function judgeClip(c) {
  const errors = [];
  const warnings = [];
  const aspect = c.width / c.height;
  if (Math.abs(aspect - LIMITS.aspect) > LIMITS.aspectTolerance) {
    errors.push(`Must be vertical 9:16; this clip is ${c.width}×${c.height}.`);
  }
  if (Math.min(c.width, c.height) < LIMITS.minWidth) {
    errors.push(`Too small: at least ${LIMITS.minWidth} px wide is needed (got ${Math.min(c.width, c.height)}).`);
  }
  if (c.durationSec < LIMITS.minSec || c.durationSec > LIMITS.maxSec) {
    errors.push(`Length should be about 5 s (${LIMITS.minSec}–${LIMITS.maxSec} s); got ${c.durationSec.toFixed(1)} s.`);
  }
  if (c.fps < LIMITS.minFps) warnings.push(`Low frame rate (${Math.round(c.fps)} fps); 24–30 fps looks smoother.`);
  if (c.loopPsnr !== null && c.loopPsnr < LIMITS.loopPsnrDb) {
    warnings.push(`The loop may jump: first and last frames differ (${c.loopPsnr.toFixed(1)} dB). Regenerate or trim for a seamless loop.`);
  }
  return { ok: errors.length === 0, errors, warnings };
}

/** Output frame rate: the source rate, capped at 30. Raising 24 fps to 30 repeats frames and judders. */
export const outputFps = (fps) => Math.min(fps, 30);

/**
 * Which converted hero clips are copied into the app bundle (mobile/assets/video), from name-map.json `app`.
 * @param {Array<{name:string, kind:string, output:string|null}>} results
 * @param {{app?: Record<string, string>}} map hero name → asset base name, e.g. "welcome"
 * @returns {Array<{from:string, to:string}>} paths relative to the ingest output and the asset folder
 */
export function appAssetsFor(results, map) {
  const app = map.app ?? {};
  return results
    .filter((r) => r.kind === 'hero' && r.output && r.name in app)
    .map((r) => ({ from: `${r.output}/loop.mp4`, to: `${app[r.name]}.mp4` }));
}
