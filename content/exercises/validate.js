// Content-pipeline validation for exercises.json (Constitution IV Video Gate, VI captions, FR-013).
// Pure: takes the parsed exercises and a file-exists check; returns errors and warnings.

export const MIN_EXERCISES = 150;
export const LIMITATION_TAGS = ['knee', 'lower_back', 'shoulder', 'wrist', 'elbow', 'hip', 'ankle', 'neck'];
export const LANGUAGES = ['en', 'fr'];

/**
 * @param {Array<object>} exercises
 * @param {{ production: boolean, captionExists: (relativePath: string) => boolean }} options
 * @returns {{ errors: string[], warnings: string[], exercises: Array<object> }}
 *   `exercises` is the list to seed: in dev, variation links to unknown slugs are cleared.
 */
export function validateExercises(exercises, { production, captionExists }) {
  const errors = [];
  const warnings = [];
  const slugs = new Set(exercises.map((e) => e.slug));

  if (slugs.size !== exercises.length) errors.push('Duplicate slugs in exercises.json');

  const countMessage = `Only ${exercises.length} exercises; at least ${MIN_EXERCISES} are required at launch (FR-013).`;
  if (exercises.length < MIN_EXERCISES) (production ? errors : warnings).push(countMessage);

  const toSeed = exercises.map((e) => {
    if (!e.video_front_url) errors.push(`VIDEO_GATE: ${e.slug} has no video_front_url`);
    if (!(e.video_duration_sec >= 5 && e.video_duration_sec <= 15)) {
      errors.push(`${e.slug}: video_duration_sec must be 5–15`);
    }
    for (const lang of LANGUAGES) {
      const path = e[`captions_${lang}_url`];
      if (!path) errors.push(`CAPTIONS: ${e.slug} has no captions_${lang}_url`);
      else if (!captionExists(path)) errors.push(`CAPTIONS: ${e.slug} caption file not found: ${path}`);
    }
    const unknownTags = (e.contraindications ?? []).filter((t) => !LIMITATION_TAGS.includes(t));
    if (unknownTags.length) errors.push(`${e.slug}: unknown contraindications ${unknownTags.join(', ')}`);

    const out = { ...e };
    for (const key of ['variation_easier_slug', 'variation_harder_slug']) {
      if (e[key] && !slugs.has(e[key])) {
        const message = `${e.slug}: ${key} '${e[key]}' is not in exercises.json`;
        if (production) errors.push(message);
        else {
          warnings.push(`${message} — cleared for this seed`);
          out[key] = null;
        }
      }
    }
    return out;
  });

  return { errors, warnings, exercises: toSeed };
}
