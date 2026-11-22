#!/usr/bin/env node
// Writes design/video-prompts-batch-6.md from pending-batch-6.js and adds the clips to name-map.json (as null).
import { readFileSync, writeFileSync } from 'node:fs';
import { expandBatch6 } from './pending-batch-6.js';

const FIRST = 133;
const EQ = {
  barbell: 'a matte black barbell with black plates', dumbbell: 'matte black dumbbells or a kettlebell', cable: 'a matte black cable station',
  machine: 'a matte black plate-loaded or selectorized machine', bands: 'a dark resistance band', pull_up_bar: 'a pull-up bar',
  dip_station: 'a dip station', bench: 'a black adjustable bench', smith_machine: 'a matte black Smith machine (bar fixed on two vertical guide rails)',
  trap_bar: 'a matte black hexagonal trap bar with raised handles', suspension: 'black suspension trainer straps anchored overhead', bodyweight: '',
};
const VIEW = { side: 'Camera: side view, full body in frame.', front: 'Camera: front view, full body in frame.', 'three-quarter': 'Camera: front three-quarter view, full body in frame.', back: 'Camera: straight behind, full body in frame.' };
const list = expandBatch6();
const rows = list.map((e, i) => `| ${FIRST + i} | \`${e._clip}\` | ${e.equipment.join(' + ')} | ${e._lead} | no | To do |`);
const prompts = list.map((e, i) => {
  const gear = e.equipment.map((x) => EQ[x]).filter(Boolean).join(', ');
  return `**${FIRST + i} · \`${e._clip}\`** (${e._lead}) — ${e.name_en}\n\n> ${/^[AEIOU]/.test(e._lead) ? "An" : "A"} ${e._lead} performs ${/^[aeiou]/i.test(e.name_en) ? "an" : "a"} ${e.name_en.replace(/Smith/g, "Smith").toLowerCase().replace("smith", "Smith")}${gear ? ` using ${gear}` : ''}. ${VIEW[e._view]} ${e.cues_en.join(' ')} Two full, slow reps with the full range of motion, ending exactly where it started. Avoid: ${e.common_mistakes_en.join('; ').toLowerCase()}.\n`;
});
const black = list.filter((e) => e._lead.startsWith('Black')).length;
const md = `# Tekto video prompt pack: batch 6 (modern gym equipment)

Status: **0 of ${list.length} delivered** (written 2026-11-21). Waiting for Flow credits.

Batch 6 widens the library to the equipment people find in a modern gym: Smith machine, plate-loaded and selectorized machines (pendulum squat, belt squat, chest-supported row, hip thrust machine, reverse hyper), cable variations, trap bar, landmine (a barbell in a landmine or a corner), suspension straps, and more dumbbell, kettlebell and bodyweight choices. It also adds the variation partners the library was missing (single-leg leg extension, pause squat, deficit deadlift, chin-up, assisted pull-up).

The exercise data (names, cues, mistakes, muscles, equipment, variations, in English and French) is ready in [\`content/exercises/pending-batch-6.js\`](../content/exercises/pending-batch-6.js). This file is generated from it by \`node make-batch6-brief.js\`: edit the data, not this file, except for the **Status** column.

**Same rules, settings, base style and negative prompt as [batch 4](video-prompts-batch-4.md).** Clips 133–${FIRST + list.length - 1}. Casting: ${black} of ${list.length} leads are Black (at least half, research §16).

**Smith machine clips add to the negative prompt:** "bar tilting, bar leaving the rails, rails bending". **Suspension clips add:** "straps tangling, extra straps".

## When a clip passes review

1. Put it in \`design/videos/\` and run \`cd content/videos && node ingest.js\`.
2. Review the movement frame by frame and record the form review (T141). Set the status below.
3. Write \`captions/<slug>_en.vtt\` and \`_fr.vtt\` from the cues.
4. \`cd content/exercises && node promote.js <slug>\`: it moves the exercise into \`exercises.json\` and maps the clip.

## Tracker

| # | File | Equipment | Lead | In library | Status |
|---|---|---|---|---|---|
${rows.join('\n')}

## Prompts

Paste the base style first, then the prompt.

${prompts.join('\n')}`;
writeFileSync(new URL('../../design/video-prompts-batch-6.md', import.meta.url), md);

const mapUrl = new URL('../videos/name-map.json', import.meta.url);
const map = JSON.parse(readFileSync(mapUrl, 'utf8'));
for (const e of list) {
  const k = e._clip.replace(/\.mp4$/, '');
  if (!(k in map.exercises)) map.exercises[k] = null;
}
writeFileSync(mapUrl, JSON.stringify(map, null, 2) + '\n');
console.log(`${list.length} clips, ${black} Black leads`);
