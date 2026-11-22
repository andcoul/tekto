// T150 / T152 — equipment vocabulary (spec FR-001, FR-013, clarified 2026-11-20).
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/models/equipment.dart';

void main() {
  test('the quiz offers eleven choices; bodyweight is not one of them', () {
    expect(kEquipmentChoices, [
      'barbell', 'dumbbell', 'cable', 'machine', 'bands', 'pull_up_bar', 'dip_station', 'bench', //
      'smith_machine', 'trap_bar', 'suspension',
    ]);
    expect(kEquipmentChoices.contains(kBodyweight), isFalse);
  });

  test('withBodyweight always adds bodyweight once, keeping the order', () {
    expect(withBodyweight(const []), ['bodyweight']);
    expect(withBodyweight(const ['dumbbell']), ['dumbbell', 'bodyweight']);
    expect(withBodyweight(const ['bodyweight', 'dumbbell']), ['bodyweight', 'dumbbell']);
  });

  test('legacy profiles are remapped like migration 014', () {
    Set<String> r(List<String> e) => remapLegacyEquipment(e).toSet();
    expect(r(['dumbbell']), {'dumbbell', 'bench', 'bodyweight'});
    expect(r(['barbell', 'dumbbell', 'cable', 'bodyweight']),
        {'barbell', 'dumbbell', 'cable', 'machine', 'bench', 'pull_up_bar', 'dip_station', 'bodyweight'});
    expect(r(['cable']), {'cable', 'machine', 'bodyweight'});
    expect(r(['bands']), {'bands', 'bodyweight'});
    expect(r([]), {'bodyweight'});
  });
}
