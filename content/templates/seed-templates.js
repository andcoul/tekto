#!/usr/bin/env node
/**
 * Seeds plan_templates from content/templates/*.json (T035). Run after seed-exercises.js.
 *
 * Usage: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node seed-templates.js
 *
 * Video Gate (Constitution IV): every exercise_slug must exist in `exercises` with a
 * video_front_url, or nothing is written.
 * Volume (FR-002a, Constitution III): a template's weekly sets per primary muscle must not exceed
 * the maximum for its level, or nothing is written.
 */
import { createClient } from '@supabase/supabase-js';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
// Same values as VOLUME_BOUNDS in supabase/functions/_shared/plan-validator.ts — keep in sync.
const VOLUME_MAX = { beginner: 14, intermediate: 18, advanced: 22 };
const REQUIRED = ['slug', 'level', 'days_per_week', 'equipment_required', 'name_en', 'name_fr', 'weeks_total', 'sessions'];

async function main() {
  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error('❌ Missing environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY');
    process.exit(1);
  }
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const templates = readdirSync(here)
    .filter((f) => f.endsWith('.json') && !f.startsWith('package'))
    .map((f) => ({ file: f, body: JSON.parse(readFileSync(join(here, f), 'utf8')) }));

  const { data: exercises, error } = await supabase.from('exercises').select('slug, video_front_url, muscle_primary, equipment');
  if (error) throw new Error(`Cannot read exercises: ${error.message}`);
  const withVideo = new Set(exercises.filter((e) => e.video_front_url).map((e) => e.slug));
  const musclesOf = new Map(exercises.map((e) => [e.slug, e.muscle_primary ?? []]));
  const equipmentOf = new Map(exercises.map((e) => [e.slug, e.equipment ?? []]));

  const errors = [];
  for (const { file, body } of templates) {
    for (const key of REQUIRED) if (body[key] === undefined) errors.push(`${file}: missing '${key}'`);
    for (const s of body.sessions ?? []) {
      for (const e of s.exercises ?? []) {
        if (!withVideo.has(e.exercise_slug)) errors.push(`VIDEO_GATE: ${file} ${s.ref}: '${e.exercise_slug}' has no video`);
      }
    }
    errors.push(...volumeErrors(file, body, musclesOf));
    errors.push(...equipmentErrors(file, body, equipmentOf));
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

/** Exercises needing equipment the template does not list in `equipment_required` (FR-013; bodyweight is free). */
export function equipmentErrors(file, body, equipmentOf) {
  const allowed = new Set([...(body.equipment_required ?? []), 'bodyweight']);
  const errors = [];
  for (const s of body.sessions ?? []) {
    for (const e of s.exercises ?? []) {
      const missing = (equipmentOf.get(e.exercise_slug) ?? []).filter((q) => !allowed.has(q));
      if (missing.length) errors.push(`EQUIPMENT: ${file} ${s.ref}: '${e.exercise_slug}' needs ${missing.join(', ')}, not in equipment_required`);
    }
  }
  return errors;
}

/** Weekly sets per primary muscle over the template's sessions, against its level maximum. */
export function volumeErrors(file, body, musclesOf) {
  const max = VOLUME_MAX[body.level];
  if (max === undefined) return [`${file}: unknown level '${body.level}'`];
  const sets = new Map();
  for (const s of body.sessions ?? []) {
    for (const e of s.exercises ?? []) {
      for (const m of musclesOf.get(e.exercise_slug) ?? []) sets.set(m, (sets.get(m) ?? 0) + e.sets);
    }
  }
  return [...sets]
    .filter(([, n]) => n > max)
    .map(([m, n]) => `VOLUME: ${file}: ${m} has ${n} sets/week; maximum for ${body.level} is ${max}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main().catch((err) => {
  console.error('❌', err.message ?? err);
  process.exit(1);
});
