// T045 — PR detection (Constitution V). Written before the T048 update.
// The formula must match the server trigger `update_personal_record()`
// (supabase/migrations/005_clarifications.sql): e1RM = weight × (1 + reps / 30),
// with no special case for single reps, and sets at 0 kg ignored.
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/workout/domain/pr_detection_service.dart';

void main() {
  const service = PRDetectionService();

  group('compute (Epley, same as the DB trigger)', () {
    test('multiple reps: 100 kg × 5 = 116.67', () {
      expect(service.compute(weightKg: 100, reps: 5), closeTo(116.67, 0.01));
    });

    test('a single rep uses the same formula as the server: 100 kg × 1 = 103.33', () {
      expect(service.compute(weightKg: 100, reps: 1), closeTo(103.33, 0.01));
    });

    test('zero reps → 0', () {
      expect(service.compute(weightKg: 100, reps: 0), 0);
    });

    test('zero weight → 0', () {
      expect(service.compute(weightKg: 0, reps: 10), 0);
    });
  });

  group('isPR', () {
    test('first loaded set for an exercise is a PR', () {
      expect(service.isPR(weightKg: 100, reps: 5, currentBestE1rm: null), isTrue);
    });

    test('true when the new e1RM is above the stored best', () {
      expect(service.isPR(weightKg: 100, reps: 5, currentBestE1rm: 110.83), isTrue);
    });

    test('false when the new e1RM is below the stored best', () {
      expect(service.isPR(weightKg: 100, reps: 5, currentBestE1rm: 120.0), isFalse);
    });

    test('false when the new e1RM equals the stored best (must exceed it)', () {
      final best = service.compute(weightKg: 100, reps: 5);
      expect(service.isPR(weightKg: 100, reps: 5, currentBestE1rm: best), isFalse);
    });

    test('more reps at the same weight can beat the record', () {
      expect(service.isPR(weightKg: 100, reps: 8, currentBestE1rm: 116.67), isTrue);
    });

    test('a single rep is compared with the server formula', () {
      // 100 × 1 → 103.33 locally and on the server; a stored best of 101 is beaten.
      expect(service.isPR(weightKg: 100, reps: 1, currentBestE1rm: 101), isTrue);
    });

    test('sets at 0 kg (bodyweight) never count as PRs, even with no record', () {
      expect(service.isPR(weightKg: 0, reps: 20, currentBestE1rm: null), isFalse);
      expect(service.isPR(weightKg: 0, reps: 20, currentBestE1rm: 0), isFalse);
    });

    test('zero reps is never a PR', () {
      expect(service.isPR(weightKg: 100, reps: 0, currentBestE1rm: null), isFalse);
    });

    test('negative input is never a PR', () {
      expect(service.isPR(weightKg: -5, reps: 5, currentBestE1rm: null), isFalse);
      expect(service.isPR(weightKg: 50, reps: -1, currentBestE1rm: null), isFalse);
    });
  });
}
