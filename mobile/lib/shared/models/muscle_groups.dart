// Muscle groups shown to users (focus muscles FR-052, recovery FR-051, feed maps FR-049) and how
// they map to the library's `muscle_primary` values. Same table as FOCUS_MUSCLES in
// supabase/functions/_shared/template-plan-builder.ts and the CHECK in migration 016.

/// Display order of the 15 groups (focus picker, recovery list).
const kMuscleGroups = [
  'chest', 'shoulders', 'triceps', 'back', 'biceps', 'traps', 'forearms', 'quads', //
  'hamstrings', 'glutes', 'abductors', 'adductors', 'calves', 'abs', 'lower_back',
];

/// Group → library muscles.
const kGroupMuscles = <String, List<String>>{
  'chest': ['chest', 'upper_chest'],
  'shoulders': ['shoulders', 'front_deltoid', 'rear_deltoid'],
  'triceps': ['triceps'],
  'back': ['lats', 'rhomboids'],
  'biceps': ['biceps'],
  'traps': ['traps'],
  'forearms': ['forearms'],
  'quads': ['quadriceps', 'quads'],
  'hamstrings': ['hamstrings'],
  'glutes': ['glutes'],
  'abductors': ['abductors'],
  'adductors': ['adductors'],
  'calves': ['calves'],
  'abs': ['core'],
  'lower_back': ['erectors'],
};

/// Groups needing ~72 h to recover; the others ~48 h (FR-051).
const kBigMuscleGroups = {'chest', 'back', 'quads', 'hamstrings', 'glutes'};

/// The group a library muscle belongs to, or null (hip flexors, for example).
String? muscleGroupOf(String libraryMuscle) {
  for (final e in kGroupMuscles.entries) {
    if (e.value.contains(libraryMuscle)) return e.key;
  }
  return null;
}

const maxFocusMuscles = 2;

/// Localized label for a group.
String muscleGroupLabel(String group, String languageCode) {
  const en = {
    'chest': 'Chest', 'shoulders': 'Shoulders', 'triceps': 'Triceps', 'back': 'Back', 'biceps': 'Biceps', //
    'traps': 'Traps', 'forearms': 'Forearms', 'quads': 'Quads', 'hamstrings': 'Hamstrings', 'glutes': 'Glutes',
    'abductors': 'Abductors', 'adductors': 'Adductors', 'calves': 'Calves', 'abs': 'Abs', 'lower_back': 'Lower back',
  };
  const fr = {
    'chest': 'Pectoraux', 'shoulders': 'Épaules', 'triceps': 'Triceps', 'back': 'Dos', 'biceps': 'Biceps', //
    'traps': 'Trapèzes', 'forearms': 'Avant-bras', 'quads': 'Quadriceps', 'hamstrings': 'Ischios',
    'glutes': 'Fessiers', 'abductors': 'Abducteurs', 'adductors': 'Adducteurs', 'calves': 'Mollets', 'abs': 'Abdos',
    'lower_back': 'Lombaires',
  };
  return (languageCode == 'fr' ? fr : en)[group] ?? group;
}
