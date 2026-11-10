import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/form_check/rep_counter.dart';

// ---------------------------------------------------------------------------
// T082 — RepCounter unit tests
// ---------------------------------------------------------------------------

void main() {
  group('RepCounter — squat', () {
    late RepCounter counter;

    setUp(() {
      counter = RepCounter(liftKey: 'squat');
    });

    test('counts exactly 5 clean squat reps', () {
      for (int i = 0; i < 5; i++) {
        _doCleanSquat(counter);
      }
      expect(counter.repCount, equals(5));
      expect(counter.noRepCount, equals(0));
    });

    test('does NOT count a partial rep that reverses before bottom threshold', () {
      // Partial: descend to 120° (above 90° bottom threshold), then ascend
      counter.update(170); // neutral
      counter.update(140); // descending
      counter.update(120); // above bottom (90°) — no-rep zone
      counter.update(145); // ascending WITHOUT reaching bottom → no-rep
      counter.update(170); // back to neutral

      expect(counter.repCount, equals(0));
      expect(counter.noRepCount, equals(1));
    });

    test('counts rep when knee angle reaches bottom threshold', () {
      _doCleanSquat(counter);
      expect(counter.repCount, equals(1));
    });

    test('resets counter to 0', () {
      _doCleanSquat(counter);
      _doCleanSquat(counter);
      expect(counter.repCount, equals(2));

      counter.reset();
      expect(counter.repCount, equals(0));
      expect(counter.noRepCount, equals(0));
    });

    test('handles multiple partial reps followed by clean reps', () {
      // 1 partial (no-rep)
      counter.update(170);
      counter.update(130);
      counter.update(135); // reverses above bottom
      counter.update(170);

      expect(counter.noRepCount, equals(1));
      expect(counter.repCount, equals(0));

      // 2 clean reps
      _doCleanSquat(counter);
      _doCleanSquat(counter);

      expect(counter.repCount, equals(2));
      expect(counter.noRepCount, equals(1));
    });
  });
}

// ---------------------------------------------------------------------------
// Helper: simulate a complete squat rep cycle
// ---------------------------------------------------------------------------

void _doCleanSquat(RepCounter counter) {
  // Standing → descent → bottom → ascent → standing
  counter.update(170); // neutral / standing
  counter.update(150); // descending start
  counter.update(120); // mid-descent
  counter.update(85);  // bottom (< 90° threshold)
  counter.update(100); // ascending
  counter.update(130); // mid-ascent
  counter.update(165); // back to top
}
