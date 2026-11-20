#!/usr/bin/env node
// Checks and converts the video loops made from design/video-prompts.md.
//
//   node ingest.js [inputDir] [outputDir]
//   defaults: ../../design/videos  →  ./out
//
// For each clip it:
//   1. works out the exercise or screen from the file name (name-map.json),
//   2. checks it is vertical 9:16, 4–15 s, at least 720 px wide, and loops cleanly,
//   3. writes   out/<exercise-slug | hero/name>/loop.mp4   H.264 720×1280, source frame rate (≤ 30 fps), no audio
//               out/.../poster.jpg   first frame, full size (shown before the video plays)
//               out/.../thumb.jpg    360 px wide (library tiles, lists)
//   4. writes   out/manifest.json   with every result, for the upload step,
//   5. copies the hero clips listed in name-map.json `app` into mobile/assets/video
//      (welcome and paywall clips, T132). Their captions (_en.vtt / _fr.vtt) live there too.
// Needs ffmpeg and ffprobe on PATH. Nothing is uploaded: Cloudflare Stream upload
// happens with the seed step once staging exists (T114).
import { execFileSync, spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { appAssetsFor, judgeClip, outputFps, resolveTarget } from './checks.js';

const here = dirname(fileURLToPath(import.meta.url));
const inputDir = resolve(process.argv[2] ?? join(here, '../../design/videos'));
const outputDir = resolve(process.argv[3] ?? join(here, 'out'));
const appAssetDir = join(here, '../../mobile/assets/video');

const map = JSON.parse(readFileSync(join(here, 'name-map.json'), 'utf8'));
const library = new Set(JSON.parse(readFileSync(join(here, '../exercises/exercises.json'), 'utf8')).map((e) => e.slug));

const run = (cmd, args) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });

function probe(file) {
  const out = JSON.parse(run('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries',
    'stream=width,height,r_frame_rate:stream_tags=rotate:stream_side_data=rotation:format=duration', '-of', 'json', file]));
  const s = out.streams[0];
  let { width, height } = s;
  const rotation = Math.abs(Number(s.tags?.rotate ?? s.side_data_list?.find((d) => 'rotation' in d)?.rotation ?? 0));
  if (rotation === 90 || rotation === 270) [width, height] = [height, width]; // phone clips stored sideways
  const [n, d] = s.r_frame_rate.split('/').map(Number);
  return { width, height, fps: d ? n / d : n, durationSec: Number(out.format.duration) };
}

/** PSNR between the first and the last frame, in dB (higher = more alike). */
function loopPsnr(file, tmp) {
  const first = join(tmp, 'first.png');
  const last = join(tmp, 'last.png');
  try {
    run('ffmpeg', ['-v', 'error', '-y', '-i', file, '-vf', 'scale=180:-2', '-frames:v', '1', first]);
    run('ffmpeg', ['-v', 'error', '-y', '-sseof', '-0.2', '-i', file, '-vf', 'scale=180:-2', '-update', '1', last]);
    // ffmpeg prints the psnr stats on stderr.
    const res = spawnSync('ffmpeg', ['-i', first, '-i', last, '-lavfi', 'psnr', '-f', 'null', '-'], { encoding: 'utf8' });
    return parsePsnr(`${res.stderr}${res.stdout}`);
  } catch {
    return null;
  }
}
const parsePsnr = (text) => {
  const m = /average:(inf|[\d.]+)/.exec(text);
  if (!m) return null;
  return m[1] === 'inf' ? 99 : Number(m[1]);
};

function convert(file, dest, fps) {
  mkdirSync(dest, { recursive: true });
  run('ffmpeg', ['-v', 'error', '-y', '-i', file, '-an',
    '-vf', `scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,fps=${outputFps(fps)},format=yuv420p`,
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '22', '-profile:v', 'high', '-movflags', '+faststart',
    join(dest, 'loop.mp4')]);
  run('ffmpeg', ['-v', 'error', '-y', '-i', join(dest, 'loop.mp4'), '-frames:v', '1', '-q:v', '3', join(dest, 'poster.jpg')]);
  run('ffmpeg', ['-v', 'error', '-y', '-i', join(dest, 'poster.jpg'), '-vf', 'scale=360:-2', '-q:v', '4', join(dest, 'thumb.jpg')]);
}

if (!existsSync(inputDir)) {
  console.error(`No folder at ${inputDir}. Put the clips there (names from design/video-prompts.md) and run again.`);
  process.exit(1);
}
const files = readdirSync(inputDir).filter((f) => /\.(mp4|mov|m4v|webm)$/i.test(f)).sort();
if (files.length === 0) {
  console.error(`No video files in ${inputDir}.`);
  process.exit(1);
}

mkdirSync(outputDir, { recursive: true });
const tmp = mkdtempSync(join(tmpdir(), 'tekto-video-'));
const results = [];
for (const f of files) {
  const file = join(inputDir, f);
  const target = resolveTarget(f, map, library);
  const entry = { file: f, ...target, checks: null, output: null };
  try {
    const info = probe(file);
    const psnr = loopPsnr(file, tmp);
    const verdict = judgeClip({ ...info, loopPsnr: psnr });
    entry.checks = { ...info, loopPsnr: psnr, ...verdict };
    if (verdict.ok && target.kind !== 'unknown') {
      const sub = target.kind === 'hero' ? join('hero', target.name) : (target.slug ?? join('pending', target.name));
      convert(file, join(outputDir, sub), info.fps);
      entry.output = sub;
    }
  } catch (e) {
    entry.checks = { ok: false, errors: [`Could not read the video: ${String(e.message).split('\n')[0]}`], warnings: [] };
  }
  results.push(entry);
}
rmSync(tmp, { recursive: true, force: true });
writeFileSync(join(outputDir, 'manifest.json'), JSON.stringify({ createdAt: new Date().toISOString(), results }, null, 2) + '\n');

// Record each mapped clip's real length in the library (FR-014, T147).
const exercisesPath = join(here, '../exercises/exercises.json');
const exercises = JSON.parse(readFileSync(exercisesPath, 'utf8'));
let lengthsUpdated = 0;
for (const r of results) {
  const ex = r.slug && exercises.find((e) => e.slug === r.slug);
  if (!ex || !r.checks?.durationSec) continue;
  const sec = Math.round(r.checks.durationSec);
  if (ex.video_duration_sec !== sec) [ex.video_duration_sec, lengthsUpdated] = [sec, lengthsUpdated + 1];
}
if (lengthsUpdated) writeFileSync(exercisesPath, JSON.stringify(exercises, null, 2) + '\n');

const bundled = appAssetsFor(results, map);
for (const { from, to } of bundled) copyFileSync(join(outputDir, from), join(appAssetDir, to));

// ── Report ──────────────────────────────────────────────────────────────
const ready = results.filter((r) => r.output && !r.problem);
const pending = results.filter((r) => r.output && r.problem);
const failed = results.filter((r) => !r.output);
const line = (r) => {
  const where = r.kind === 'hero' ? `screen ${r.screen}` : r.slug ? `exercise ${r.slug}` : 'no exercise yet';
  const notes = [...(r.checks?.errors ?? []), ...(r.checks?.warnings ?? []), ...(r.problem ? [r.problem] : [])];
  return `  ${r.file.padEnd(34)} → ${where}${notes.length ? '\n      - ' + notes.join('\n      - ') : ''}`;
};
console.log(`\n${files.length} clips checked in ${inputDir}\n`);
if (ready.length) console.log(`Ready (${ready.length}):\n${ready.map(line).join('\n')}\n`);
if (pending.length) console.log(`Converted, but the exercise is not in the library yet (${pending.length}):\n${pending.map(line).join('\n')}\n`);
if (failed.length) console.log(`Needs a new clip (${failed.length}):\n${failed.map(line).join('\n')}\n`);
const expected = [...Object.keys(map.exercises), ...Object.keys(map.heroes)];
const missing = expected.filter((n) => !results.some((r) => r.name === n));
if (missing.length) console.log(`Not received yet (${missing.length}): ${missing.join(', ')}\n`);
if (bundled.length) console.log(`Bundled with the app (${appAssetDir}): ${bundled.map((b) => b.to).join(', ')}\n`);
console.log(`Output: ${outputDir} (manifest.json lists everything)`);
process.exit(failed.length ? 2 : 0);
