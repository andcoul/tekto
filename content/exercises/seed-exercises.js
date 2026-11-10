#!/usr/bin/env node
/**
 * Seed script: reads exercises.json and upserts all rows to the Supabase exercises table.
 *
 * Usage:
 *   SUPABASE_URL=https://... SUPABASE_SERVICE_ROLE_KEY=... node seed-exercises.js
 *
 * Video Gate enforcement: every exercise MUST have a non-null video_front_url before insert.
 * Exercises without a video are blocked at the content pipeline level (Principle IV).
 */

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ Missing environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function main() {
  const raw = readFileSync(join(__dirname, 'exercises.json'), 'utf8');
  const exercises = JSON.parse(raw);

  console.log(`📋 Loaded ${exercises.length} exercises from exercises.json`);

  // ── Video Gate: reject any exercise without video_front_url ──────────────
  const noVideo = exercises.filter((e) => !e.video_front_url);
  if (noVideo.length > 0) {
    console.error(
      `❌ VIDEO_GATE: ${noVideo.length} exercise(s) have no video_front_url:\n` +
        noVideo.map((e) => `   - ${e.slug}`).join('\n'),
    );
    console.error('Fix these exercises before seeding. No rows were inserted.');
    process.exit(1);
  }

  console.log('✅ Video Gate passed — all exercises have video_front_url');

  // ── Upsert in batches of 50 ───────────────────────────────────────────────
  const BATCH = 50;
  let inserted = 0;

  for (let i = 0; i < exercises.length; i += BATCH) {
    const batch = exercises.slice(i, i + BATCH);
    const { error } = await supabase.from('exercises').upsert(batch, {
      onConflict: 'slug',
      ignoreDuplicates: false,
    });

    if (error) {
      console.error(`❌ Error upserting batch ${i / BATCH + 1}:`, error.message);
      process.exit(1);
    }

    inserted += batch.length;
    console.log(`   ✓ Upserted ${inserted}/${exercises.length} exercises`);
  }

  console.log(`\n✅ Done. ${inserted} exercises seeded.`);
}

main().catch((err) => {
  console.error('❌ Unexpected error:', err);
  process.exit(1);
});
