#!/usr/bin/env node
/**
 * Seeds plan_templates from content/templates/*.json (T035). Run after seed-exercises.js.
 *
 * Usage: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node seed-templates.js
 *
 * Video Gate (Constitution IV): every exercise_slug must exist in `exercises` with a
 * video_front_url, or nothing is written.
 */
import { createClient } from '@supabase/supabase-js';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ Missing environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const REQUIRED = ['slug', 'level', 'days_per_week', 'equipment_required', 'name_en', 'name_fr', 'weeks_total', 'sessions'];

async function main() {
  const templates = readdirSync(here)
    .filter((f) => f.endsWith('.json') && !f.startsWith('package'))
    .map((f) => ({ file: f, body: JSON.parse(readFileSync(join(here, f), 'utf8')) }));

  const { data: exercises, error } = await supabase.from('exercises').select('slug, video_front_url');
  if (error) throw new Error(`Cannot read exercises: ${error.message}`);
  const withVideo = new Set(exercises.filter((e) => e.video_front_url).map((e) => e.slug));

  const errors = [];
  for (const { file, body } of templates) {
    for (const key of REQUIRED) if (body[key] === undefined) errors.push(`${file}: missing '${key}'`);
    for (const s of body.sessions ?? []) {
      for (const e of s.exercises ?? []) {
        if (!withVideo.has(e.exercise_slug)) errors.push(`VIDEO_GATE: ${file} ${s.ref}: '${e.exercise_slug}' has no video`);
      }
    }
  }
  if (errors.length) {
    errors.forEach((e) => console.error(`❌ ${e}`));
    console.error('No templates were written.');
    process.exit(1);
  }

  const rows = templates.map(({ body }) => ({
    slug: body.slug,
    level: body.level,
    days_per_week: body.days_per_week,
    equipment_required: body.equipment_required,
    body,
    updated_at: new Date().toISOString(),
  }));
  const { error: upsertError } = await supabase.from('plan_templates').upsert(rows, { onConflict: 'slug' });
  if (upsertError) throw new Error(`Upsert failed: ${upsertError.message}`);
  console.log(`✅ ${rows.length} templates seeded: ${rows.map((r) => r.slug).join(', ')}`);
}

main().catch((err) => {
  console.error('❌', err.message ?? err);
  process.exit(1);
});
