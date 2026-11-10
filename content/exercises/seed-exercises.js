#!/usr/bin/env node
/**
 * Seeds the exercise library from exercises.json (the only allowed way to add exercises —
 * Constitution IV).
 *
 * Usage:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node seed-exercises.js [--production]
 *
 * Steps:
 *   1. Validate (validate.js): Video Gate, EN/FR caption files, duration, contraindication tags,
 *      ≥ 150 exercises (warning in dev, error with --production), variation links.
 *   2. Upload each WebVTT caption file to the public Storage bucket `captions` and replace the
 *      repo path with its public URL. (Research §15 planned Cloudflare Stream caption tracks; the
 *      player loads captions by URL, so a plain public file is enough and works locally.)
 *   3. Upsert rows without variation links, then set the links (self-referencing foreign keys).
 */
import { createClient } from '@supabase/supabase-js';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateExercises } from './validate.js';

const here = dirname(fileURLToPath(import.meta.url));
const production = process.argv.includes('--production');
const BUCKET = 'captions';

const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('❌ Missing environment variables: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function ensureBucket() {
  const { data } = await supabase.storage.getBucket(BUCKET);
  if (data) return;
  const { error } = await supabase.storage.createBucket(BUCKET, { public: true });
  if (error) throw new Error(`Cannot create bucket '${BUCKET}': ${error.message}`);
}

async function uploadCaption(relativePath) {
  const objectPath = relativePath.replace(/^captions\//, '');
  const { error } = await supabase.storage
    .from(BUCKET)
    .upload(objectPath, readFileSync(join(here, relativePath)), { contentType: 'text/vtt', upsert: true });
  if (error) throw new Error(`Caption upload failed for ${relativePath}: ${error.message}`);
  return supabase.storage.from(BUCKET).getPublicUrl(objectPath).data.publicUrl;
}

async function main() {
  const all = JSON.parse(readFileSync(join(here, 'exercises.json'), 'utf8'));
  console.log(`📋 Loaded ${all.length} exercises (${production ? 'production' : 'dev'} mode)`);

  const { errors, warnings, exercises } = validateExercises(all, {
    production,
    captionExists: (p) => existsSync(join(here, p)),
  });
  warnings.forEach((w) => console.warn(`⚠️  ${w}`));
  if (errors.length) {
    errors.forEach((e) => console.error(`❌ ${e}`));
    console.error('No rows were written.');
    process.exit(1);
  }
  console.log('✅ Validation passed (Video Gate, captions, tags)');

  await ensureBucket();
  const rows = [];
  for (const e of exercises) {
    rows.push({
      ...e,
      captions_en_url: await uploadCaption(e.captions_en_url),
      captions_fr_url: await uploadCaption(e.captions_fr_url),
      variation_easier_slug: null,
      variation_harder_slug: null,
    });
  }
  console.log(`✅ Uploaded ${rows.length * 2} caption files to '${BUCKET}'`);

  const { error: upsertError } = await supabase.from('exercises').upsert(rows, { onConflict: 'slug' });
  if (upsertError) throw new Error(`Upsert failed: ${upsertError.message}`);

  for (const e of exercises.filter((x) => x.variation_easier_slug || x.variation_harder_slug)) {
    const { error } = await supabase
      .from('exercises')
      .update({ variation_easier_slug: e.variation_easier_slug, variation_harder_slug: e.variation_harder_slug })
      .eq('slug', e.slug);
    if (error) throw new Error(`Variation update failed for ${e.slug}: ${error.message}`);
  }

  console.log(`\n✅ Done. ${rows.length} exercises seeded.`);
}

main().catch((err) => {
  console.error('❌', err.message ?? err);
  process.exit(1);
});
