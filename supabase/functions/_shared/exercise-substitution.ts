// Exercise substitution (T014): one rule set for the plan validator flow, the free template
// builder, coach swaps and user swaps (FR-003b, FR-028, Constitution IV).
import type { Library, LibraryExercise, PlanProfile } from './plan-draft.ts';

/** Equipment that adds external load; used to rank "closest equipment". */
const LOADED = new Set(['barbell', 'dumbbell', 'cable', 'machine', 'bands', 'kettlebell']);

/** Bodyweight movements never need equipment from the user's list. */
const ALWAYS_AVAILABLE = 'bodyweight';

/** True when the user can do `ex`: every equipment item is available and no limitation is hit. */
export function isAllowed(ex: LibraryExercise, profile: PlanProfile): boolean {
  const available = new Set([...profile.equipment, ALWAYS_AVAILABLE]);
  if (!ex.equipment.every((item) => available.has(item))) return false;
  return !ex.contraindications.some((tag) => profile.limitations.includes(tag));
}

export interface SubstituteOptions {
  /** Slugs that must not be returned (e.g. already in the session). */
  exclude?: Set<string>;
  /** Target muscle when the original slug is not in the library. */
  muscle?: string;
}

/**
 * Finds a replacement for `slug`: shares the original's first primary muscle, is allowed for the
 * user, and has a video. Ranked by shared primary muscles, then equipment closeness, then slug
 * (deterministic). Returns null when no candidate exists.
 */
export function findSubstitute(
  slug: string,
  profile: PlanProfile,
  library: Library,
  options: SubstituteOptions = {},
): LibraryExercise | null {
  const original = library.get(slug);
  const targetMuscle = original?.muscle_primary[0] ?? options.muscle;
  if (!targetMuscle) return null;

  const exclude = options.exclude ?? new Set<string>();
  const candidates = [...library.values()].filter((c) =>
    c.slug !== slug &&
    !exclude.has(c.slug) &&
    c.video_front_url !== null && c.video_front_url !== '' &&
    c.muscle_primary.includes(targetMuscle) &&
    isAllowed(c, profile)
  );
  if (candidates.length === 0) return null;

  const score = (c: LibraryExercise) => {
    const sharedMuscles = original
      ? c.muscle_primary.filter((m) => original.muscle_primary.includes(m)).length
      : 1;
    return sharedMuscles * 10 + equipmentCloseness(original?.equipment ?? [], c.equipment);
  };

  candidates.sort((a, b) => score(b) - score(a) || a.slug.localeCompare(b.slug));
  return candidates[0];
}

/** 2 = same equipment, 1 = both externally loaded, 0 = otherwise. */
function equipmentCloseness(original: string[], candidate: string[]): number {
  if (original.length === 0) return 0;
  if (original.some((e) => candidate.includes(e))) return 2;
  const loaded = (list: string[]) => list.some((e) => LOADED.has(e));
  return loaded(original) && loaded(candidate) ? 1 : 0;
}
