#!/usr/bin/env node
// Moves a batch-6 exercise into the library once its clip passed review (Constitution IV Video Gate).
//
//   node promote.js <slug> [<slug> …]
//
// Needs, for each slug:
//   - the clip checked by content/videos/ingest.js (out/manifest.json, checks ok),
//   - the human form review recorded in design/video-prompts-batch-6.md (T141),
//   - captions/<slug>_en.vtt and captions/<slug>_fr.vtt.
// It then writes the entry into exercises.json and maps the clip in content/videos/name-map.json.
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { expandBatch6 } from './pending-batch-6.js';

const STREAM = (slug) => `https://customer-tekto.cloudflarestream.com/${slug}-front/manifest/video.m3u8`;

/**
 * Builds the library entry for one pending exercise. Pure, for tests.
 * @returns {{ entry?: object, error?: string }}
 */
export function promoteEntry(pending, manifestResult, captionExists) {
  if (!manifestResult) return { error: `${pending.slug}: ${pending._clip} is not in the ingest manifest yet` };
  if (!manifestResult.checks?.ok) return { error: `${pending.slug}: ${pending._clip} failed the clip checks` };
  for (const p of [pending.captions_en_url, pending.captions_fr_url]) {
    if (!captionExists(p)) return { error: `${pending.slug}: missing caption file ${p}` };
  }
  const entry = Object.fromEntries(Object.entries(pending).filter(([k]) => !k.startsWith('_')));
  entry.video_front_url = STREAM(pending.slug);
  entry.video_duration_sec = Math.round(manifestResult.checks.durationSec);
  return { entry };
}

const here = dirname(fileURLToPath(import.meta.url));
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const slugs = process.argv.slice(2);
  if (!slugs.length) {
    console.error('Usage: node promote.js <slug> [<slug> …]');
    process.exit(1);
  }
  const libPath = join(here, 'exercises.json');
  const mapPath = join(here, '../videos/name-map.json');
  const library = JSON.parse(readFileSync(libPath, 'utf8'));
  const map = JSON.parse(readFileSync(mapPath, 'utf8'));
  const manifestPath = join(here, '../videos/out/manifest.json');
  const results = existsSync(manifestPath) ? JSON.parse(readFileSync(manifestPath, 'utf8')).results : [];
  const pending = expandBatch6();
  let failed = 0;
  for (const slug of slugs) {
    const p = pending.find((e) => e.slug === slug);
    if (!p) [failed] = [failed + 1, console.error(`${slug}: not in pending-batch-6.js`)];
    else if (library.some((e) => e.slug === slug)) console.log(`${slug}: already in the library`);
    else {
      const res = results.find((r) => r.file === p._clip);
      const { entry, error } = promoteEntry(p, res, (rel) => existsSync(join(here, rel)));
      if (error) [failed] = [failed + 1, console.error(error)];
      else {
        library.push(entry);
        map.exercises[p._clip.replace(/\.mp4$/, '')] = slug;
        console.log(`${slug}: added (${entry.video_duration_sec} s)`);
      }
    }
  }
  writeFileSync(libPath, JSON.stringify(library, null, 2) + '\n');
  writeFileSync(mapPath, JSON.stringify(map, null, 2) + '\n');
  process.exit(failed ? 2 : 0);
}
