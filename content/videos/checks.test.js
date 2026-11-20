// Run with `node --test` from content/videos.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { resolveTarget, judgeClip, outputFps, appAssetsFor, LIMITS } from './checks.js';

const map = {
  exercises: { 'legs-back-squat': 'barbell-squat', 'core-plank': null },
  heroes: { 'hero-live': '2.03 Live session' },
};
const library = new Set(['barbell-squat', 'goblet-squat']);

test('an exercise clip resolves to its library slug', () => {
  assert.deepEqual(resolveTarget('legs-back-squat.mp4', map, library), {
    name: 'legs-back-squat', kind: 'exercise', slug: 'barbell-squat', problem: null,
  });
});

test('an exercise not in the library yet is flagged, not dropped', () => {
  const r = resolveTarget('core-plank.mp4', map, library);
  assert.equal(r.kind, 'exercise');
  assert.equal(r.slug, null);
  assert.match(r.problem, /not in the exercise library/);
});

test('a mapped slug that is missing from exercises.json is flagged', () => {
  const r = resolveTarget('legs-back-squat.mp4', map, new Set());
  assert.match(r.problem, /barbell-squat/);
});

test('a hero clip resolves to its screen', () => {
  assert.deepEqual(resolveTarget('hero-live.mov', map, library), {
    name: 'hero-live', kind: 'hero', slug: null, screen: '2.03 Live session', problem: null,
  });
});

test('an unknown file name is reported with the expected names', () => {
  const r = resolveTarget('squat-final-v2.mp4', map, library);
  assert.equal(r.kind, 'unknown');
  assert.match(r.problem, /file name/);
});

const good = { width: 1080, height: 1920, durationSec: 5, fps: 30, loopPsnr: 34 };

test('a vertical 5 s loop passes every check', () => {
  assert.deepEqual(judgeClip(good), { ok: true, errors: [], warnings: [] });
});

test('a horizontal clip fails', () => {
  const r = judgeClip({ ...good, width: 1920, height: 1080 });
  assert.equal(r.ok, false);
  assert.match(r.errors[0], /vertical 9:16/);
});

test('a 4:5 clip fails the aspect check', () => {
  assert.equal(judgeClip({ ...good, width: 1080, height: 1350 }).ok, false);
});

test('too short or too long fails; slightly off is fine', () => {
  assert.equal(judgeClip({ ...good, durationSec: LIMITS.minSec - 0.5 }).ok, false);
  assert.equal(judgeClip({ ...good, durationSec: LIMITS.maxSec + 1 }).ok, false);
  assert.equal(judgeClip({ ...good, durationSec: 6.2 }).ok, true);
});

test('below 720 px wide is an error; a visible loop seam is a warning only', () => {
  assert.match(judgeClip({ ...good, width: 540, height: 960 }).errors.join(' '), /720/);
  const seam = judgeClip({ ...good, loopPsnr: 18 });
  assert.equal(seam.ok, true);
  assert.match(seam.warnings[0], /loop/);
});

test('low frame rate is a warning', () => {
  assert.match(judgeClip({ ...good, fps: 15 }).warnings.join(' '), /fps/);
});

test('the frame rate is kept up to 30 fps, never padded with duplicate frames', () => {
  assert.equal(outputFps(24), 24);
  assert.equal(outputFps(23.976), 23.976);
  assert.equal(outputFps(30), 30);
  assert.equal(outputFps(60), 30);
});

test('hero clips bundled with the app get the asset name the screens load', () => {
  const m = { ...map, app: { 'hero-live': 'welcome' } };
  assert.deepEqual(appAssetsFor([{ name: 'hero-live', kind: 'hero', output: 'hero/hero-live' },
    { name: 'legs-back-squat', kind: 'exercise', output: 'barbell-squat' }], m),
  [{ from: 'hero/hero-live/loop.mp4', to: 'welcome.mp4' }]);
});

test('a hero clip that failed its checks is not bundled', () => {
  const m = { ...map, app: { 'hero-live': 'welcome' } };
  assert.deepEqual(appAssetsFor([{ name: 'hero-live', kind: 'hero', output: null }], m), []);
});
