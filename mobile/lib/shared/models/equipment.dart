// Equipment vocabulary (spec FR-001, FR-013 — clarified 2026-11-20; Smith machine, trap bar and
// suspension straps added 2026-11-21). Same list as content/exercises/validate.js EQUIPMENT and
// supabase/migrations/015.

/// Always available; never asked in the quiz.
const kBodyweight = 'bodyweight';

/// The quiz choices, in display order. Kettlebells count as `dumbbell`. "Gym" selects them all.
const kEquipmentChoices = [
  'barbell',
  'dumbbell',
  'cable',
  'machine',
  'bands',
  'pull_up_bar',
  'dip_station',
  'bench',
  'smith_machine',
  'trap_bar',
  'suspension',
];

/// The equipment list saved for a profile: the chosen items plus bodyweight.
List<String> withBodyweight(List<String> equipment) =>
    equipment.contains(kBodyweight) ? List.of(equipment) : [...equipment, kBodyweight];

/// Converts a profile saved before 2026-11-20, when `cable` also meant machines and benches, bars
/// and dip stations were never asked about, so its current plan stays valid. Mirrors migration 014.
List<String> remapLegacyEquipment(List<String> equipment) {
  final out = <String>{...equipment, kBodyweight};
  if (equipment.contains('cable')) out.add('machine');
  if (equipment.contains('barbell') || equipment.contains('dumbbell')) out.add('bench');
  if (equipment.contains('barbell') && equipment.contains('cable')) out.addAll(['pull_up_bar', 'dip_station']);
  return out.toList();
}
