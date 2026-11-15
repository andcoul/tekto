/// Display names for the `muscle_primary` vocabulary of the exercise library (EN/FR).
library;

const _labels = <String, (String, String)>{
  'quadriceps': ('Quadriceps', 'Quadriceps'),
  'quads': ('Quadriceps', 'Quadriceps'),
  'hamstrings': ('Hamstrings', 'Ischio-jambiers'),
  'glutes': ('Glutes', 'Fessiers'),
  'erectors': ('Lower back', 'Lombaires'),
  'chest': ('Chest', 'Pectoraux'),
  'upper_chest': ('Upper chest', 'Haut des pectoraux'),
  'shoulders': ('Shoulders', 'Épaules'),
  'front_deltoid': ('Front delts', 'Deltoïdes antérieurs'),
  'rear_deltoid': ('Rear delts', 'Deltoïdes postérieurs'),
  'lats': ('Lats', 'Grands dorsaux'),
  'rhomboids': ('Upper back', 'Haut du dos'),
  'traps': ('Traps', 'Trapèzes'),
  'biceps': ('Biceps', 'Biceps'),
  'triceps': ('Triceps', 'Triceps'),
  'core': ('Core', 'Sangle abdominale'),
  'calves': ('Calves', 'Mollets'),
};

/// Localized label; unknown keys fall back to the key with spaces.
String muscleLabel(String key, String languageCode) {
  final label = _labels[key];
  if (label == null) return key.replaceAll('_', ' ');
  return languageCode == 'fr' ? label.$2 : label.$1;
}
