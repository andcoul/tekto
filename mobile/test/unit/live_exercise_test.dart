// T156 — the plate calculator is for loaded barbell lifts only (FR-042; FR-001 vocabulary).
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/workout/domain/live_session.dart';

LiveExercise _ex(List<String> equipment) => LiveExercise(
      planExerciseId: 'pe', slug: 's', nameEn: 'n', nameFr: 'n', cuesEn: const [], cuesFr: const [], //
      sets: 3, repsMin: 8, repsMax: 12, restSec: 90, equipment: equipment,
    );

void main() {
  test('barbell lifts offer the plate calculator, including ones that also need a bench', () {
    expect(_ex(const ['barbell']).usesBarbell, isTrue);
    expect(_ex(const ['barbell', 'bench']).usesBarbell, isTrue);
  });

  test('a bodyweight move on a bar (inverted row) does not offer the plate calculator', () {
    expect(_ex(const ['bodyweight', 'barbell']).usesBarbell, isFalse);
    expect(_ex(const ['dumbbell']).usesBarbell, isFalse);
  });
}
