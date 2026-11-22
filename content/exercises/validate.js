// Content-pipeline validation for exercises.json (Constitution IV Video Gate, VI captions, FR-013).
// Pure: takes the parsed exercises and a file-exists check; returns errors and warnings.

export const MIN_EXERCISES = 150;
export const LIMITATION_TAGS = ['knee', 'lower_back', 'shoulder', 'wrist', 'elbow', 'hip', 'ankle', 'neck'];
export const LANGUAGES = ['en', 'fr'];
/**
 * Equipment vocabulary (FR-001, FR-013 — clarified 2026-11-20; Smith machine, trap bar and suspension
 * straps added 2026-11-21). Kettlebells count as `dumbbell`; plate-loaded machines count as `machine`;
 * landmine moves need only a `barbell` (a corner works as the anchor).
 */
export const EQUIPMENT = ['barbell', 'dumbbell', 'cable', 'machine', 'bands', 'pull_up_bar', 'dip_station', 'bench', 'smith_machine', 'smith_machine', 'trap_bar', 'suspension', 'bodyweight'];
/** The 8 form-check lifts at launch (FR-022). */
export const FORM_CHECK_LIFTS = ['squat', 'deadlift', 'bench_press', 'overhead_press', 'row', 'lunge', 'hip_thrust', 'push_up'];
/** The form-check lifts and their variants: each needs a second-angle video (FR-014). */
export const SECOND_ANGLE_FAMILIES = {
  squat: ['barbell-squat', 'goblet-squat', 'front-squat', 'bodyweight-squat', 'kettlebell-sumo-squat'],
  deadlift: ['deadlift', 'romanian-deadlift', 'sumo-deadlift', 'dumbbell-rdl'],
  bench_press: ['bench-press', 'dumbbell-bench-press', 'incline-bench-press', 'close-grip-bench-press', 'incline-dumbbell-press', 'decline-bench-press'],
  overhead_press: ['overhead-press', 'dumbbell-shoulder-press', 'push-press', 'arnold-press'],
  row: ['barbell-row', 'dumbbell-row', 'pendlay-row'],
  lunge: ['dumbbell-lunge', 'bodyweight-lunge', 'bulgarian-split-squat'],
  hip_thrust: ['hip-thrust', 'single-leg-hip-thrust', 'glute-bridge'],
  push_up: ['push-up', 'incline-push-up', 'diamond-push-up'],
};
const SECOND_ANGLE_SLUGS = new Set(Object.values(SECOND_ANGLE_FAMILIES).flat());

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
    if (!(e.video_duration_sec >= 4 && e.video_duration_sec <= 15)) {
      errors.push(`${e.slug}: video_duration_sec must be 4–15`);
    }
    const equipment = e.equipment ?? [];
    if (!equipment.length) errors.push(`${e.slug}: no equipment (use ['bodyweight'] for none)`);
    const unknownEquipment = equipment.filter((q) => !EQUIPMENT.includes(q));
    if (unknownEquipment.length) errors.push(`${e.slug}: unknown equipment ${unknownEquipment.join(', ')}`);
    if ((SECOND_ANGLE_SLUGS.has(e.slug) || e.form_check_lift_key) && !e.video_side_url) {
      (production ? errors : warnings).push(`${e.slug}: no second-angle video (form-check lift or variant, FR-014)`);
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
    if (!out.variation_easier_slug && !out.variation_harder_slug) {
      (production ? errors : warnings).push(`${e.slug}: no easier or harder variation (FR-014)`);
    }
    return out;
  });

  const lifts = new Set(exercises.map((e) => e.form_check_lift_key).filter(Boolean));
  const missingLifts = FORM_CHECK_LIFTS.filter((k) => !lifts.has(k));
  if (missingLifts.length) {
    (production ? errors : warnings).push(`Missing form-check lifts (FR-022): ${missingLifts.join(', ')}`);
  }

  return { errors, warnings, exercises: toSeed };
}
