import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/workout/domain/pr_detection_service.dart';

void main() {
  group('PRDetectionService', () {
    const service = PRDetectionService();

    test('isPR returns true when no previous record exists', () {
      expect(service.isPR(weightKg: 100, reps: 5, currentBestE1rm: null), isTrue);
    });

    test('isPR returns true when new e1RM exceeds stored best', () {
      // e1RM for 100kg × 5 = 100 × (1 + 5/30) = 116.67
      // e1RM for 95kg × 5 = 95 × (1 + 5/30) = 110.83
      const previousBest = 110.83;
      expect(
        service.isPR(weightKg: 100, reps: 5, currentBestE1rm: previousBest),
        isTrue,
      );
    });

    test('isPR returns false when new e1RM is below stored best', () {
      const previousBest = 120.0;
      expect(
        service.isPR(weightKg: 100, reps: 5, currentBestE1rm: previousBest),
        isFalse,
      );
    });

    test('isPR returns false for zero reps', () {
      expect(service.isPR(weightKg: 100, reps: 0, currentBestE1rm: null), isFalse);
    });

    test('isPR returns false for zero weight', () {
      expect(service.isPR(weightKg: 0, reps: 5, currentBestE1rm: null), isFalse);
    });

    test('compute returns weight for 1 rep', () {
      expect(service.compute(weightKg: 100, reps: 1), closeTo(100.0, 0.001));
    });

    test('compute uses Epley formula for multiple reps', () {
      // 100 × (1 + 5/30) = 100 × 1.1667 = 116.67
      expect(
        service.compute(weightKg: 100, reps: 5),
        closeTo(116.67, 0.01),
      );
    });

    test('compute returns 0 for zero reps', () {
      expect(service.compute(weightKg: 100, reps: 0), 0);
    });

    test('isPR returns true when reps improvement lifts e1RM above record', () {
      // Previous: 100kg × 5 = 116.67
      // New: 100kg × 8 = 100 × (1 + 8/30) = 126.67
      expect(
        service.isPR(weightKg: 100, reps: 8, currentBestE1rm: 116.67),
        isTrue,
      );
    });
  });
}
