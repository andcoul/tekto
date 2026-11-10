// Small, readable exercise library for unit tests (not production content).
import { type DraftExercise, type DraftPlan, type LibraryExercise, libraryFrom, type PlanProfile } from './plan-draft.ts';

const v = (slug: string) => `https://video.test/${slug}.m3u8`;

export const FIXTURE_ROWS: LibraryExercise[] = [
  { slug: 'barbell-squat', equipment: ['barbell'], muscle_primary: ['quadriceps', 'glutes'], video_front_url: v('barbell-squat'), contraindications: ['knee', 'lower_back'] },
  { slug: 'goblet-squat', equipment: ['dumbbell'], muscle_primary: ['quadriceps', 'glutes'], video_front_url: v('goblet-squat'), contraindications: ['knee'] },
  { slug: 'leg-press', equipment: ['machine'], muscle_primary: ['quadriceps', 'glutes'], video_front_url: v('leg-press'), contraindications: [] },
  { slug: 'glute-bridge', equipment: ['bodyweight'], muscle_primary: ['glutes'], video_front_url: v('glute-bridge'), contraindications: [] },
  { slug: 'bench-press', equipment: ['barbell'], muscle_primary: ['chest'], video_front_url: v('bench-press'), contraindications: ['shoulder'] },
  { slug: 'dumbbell-bench-press', equipment: ['dumbbell'], muscle_primary: ['chest'], video_front_url: v('dumbbell-bench-press'), contraindications: ['shoulder'] },
  { slug: 'push-up', equipment: ['bodyweight'], muscle_primary: ['chest'], video_front_url: v('push-up'), contraindications: ['wrist'] },
  { slug: 'cable-fly', equipment: ['cable'], muscle_primary: ['chest'], video_front_url: null, contraindications: [] },
  { slug: 'barbell-row', equipment: ['barbell'], muscle_primary: ['lats'], video_front_url: v('barbell-row'), contraindications: ['lower_back'] },
  { slug: 'dumbbell-row', equipment: ['dumbbell'], muscle_primary: ['lats'], video_front_url: v('dumbbell-row'), contraindications: [] },
  { slug: 'deadlift', equipment: ['barbell'], muscle_primary: ['hamstrings', 'glutes'], video_front_url: v('deadlift'), contraindications: ['lower_back'] },
  { slug: 'dumbbell-rdl', equipment: ['dumbbell'], muscle_primary: ['hamstrings', 'glutes'], video_front_url: v('dumbbell-rdl'), contraindications: ['lower_back'] },
];

export const LIBRARY = libraryFrom(FIXTURE_ROWS);

export function profile(overrides: Partial<PlanProfile> = {}): PlanProfile {
  return {
    level: 'intermediate',
    equipment: ['barbell', 'dumbbell', 'bodyweight'],
    limitations: [],
    session_length_min: 60,
    days_per_week: 3,
    ...overrides,
  };
}

export function ex(slug: string, overrides: Partial<DraftExercise> = {}): DraftExercise {
  return { exercise_slug: slug, sets: 3, reps_min: 8, reps_max: 12, rest_sec: 90, ...overrides };
}

/** One-week-pattern plan repeated for `weeks` weeks; days default to Mon/Wed/Fri. */
export function plan(
  exercisesPerSession: DraftExercise[][],
  { weeks = 4, days = [1, 3, 5] }: { weeks?: number; days?: number[] } = {},
): DraftPlan {
  const sessions: DraftPlan['sessions'] = [];
  for (let w = 1; w <= weeks; w++) {
    exercisesPerSession.forEach((exercises, i) => {
      sessions.push({
        week_number: w,
        day_of_week: days[i],
        name_en: `Session ${i + 1}`,
        name_fr: `Séance ${i + 1}`,
        exercises: exercises.map((e) => ({ ...e })),
      });
    });
  }
  return { name_en: 'Test plan', name_fr: 'Plan test', weeks_total: weeks, sessions };
}
