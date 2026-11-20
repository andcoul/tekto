import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/form_check/pose_analyzer.dart';
import 'package:tekto/shared/services/form_check/rep_counter.dart';

// ---------------------------------------------------------------------------
// T058 — RepCounter unit tests
// ---------------------------------------------------------------------------

/// Feeds [angles] one by one and returns how many reps were completed.
int _feed(RepCounter counter, List<double> angles) =>
    angles.where(counter.update).length;

/// Standing → bottom → standing for a squat (knee angle, degrees).
const _cleanSquat = <double>[170, 150, 120, 85, 100, 130, 165];

/// One realistic rep per launch lift, measured on the angle PoseAnalyzer uses to count it.
const _repPerLift = <String, List<double>>{
  // knee angle: standing 170°, parallel ≈ 85°
  'squat': [172, 150, 120, 88, 84, 100, 140, 168],
  // front knee angle
  'lunge': [170, 140, 110, 88, 95, 130, 166],
  // hip angle: hinged ≈ 60°, locked out ≈ 175°
  'deadlift': [175, 140, 100, 68, 62, 90, 140, 172],
  // elbow angle: arms locked ≈ 170°, bar on chest ≈ 80°
  'bench_press': [170, 140, 110, 85, 80, 110, 150, 168],
  // elbow angle: starts racked at the shoulders (≈ 80°), presses to lockout and lowers back
  'overhead_press': [85, 80, 120, 160, 172, 140, 100, 82],
  // elbow angle: arms long ≈ 165°, pulled in ≈ 75°
  'row': [168, 140, 100, 80, 75, 110, 150, 166],
  // hip angle: seat on floor ≈ 95°, full extension ≈ 175°
  'hip_thrust': [175, 150, 120, 98, 95, 130, 160, 176],
  // elbow angle: plank ≈ 170°, chest down ≈ 80°
  'push_up': [170, 140, 110, 85, 80, 110, 150, 168],
};

void main() {
  group('RepCounter — squat', () {
    late RepCounter counter;

    setUp(() => counter = RepCounter(liftKey: 'squat'));

    test('counts exactly 5 clean squat reps', () {
      for (var i = 0; i < 5; i++) {
        _feed(counter, _cleanSquat);
      }
      expect(counter.repCount, 5);
      expect(counter.noRepCount, 0);
    });

    test('a partial rep reversing before the bottom threshold is not counted', () {
      // Down to 120° (bottom is 90°), then back up.
      _feed(counter, [170, 140, 120, 145, 170]);
      expect(counter.repCount, 0);
      expect(counter.noRepCount, 1);
    });

    test('small jitter on the way down is not a reversal', () {
      _feed(counter, [170, 150, 140, 143, 120, 85, 120, 165]);
      expect(counter.repCount, 1);
      expect(counter.noRepCount, 0);
    });

    test('a pause at the bottom still counts once', () {
      _feed(counter, [170, 120, 85, 86, 84, 85, 120, 165, 168, 170]);
      expect(counter.repCount, 1);
    });

    test('partial reps followed by clean reps', () {
      _feed(counter, [170, 130, 135, 170]); // shallow dip
      _feed(counter, [170, 130, 145, 170]); // another shallow dip
      _feed(counter, _cleanSquat);
      _feed(counter, _cleanSquat);
      expect(counter.noRepCount, 2);
      expect(counter.repCount, 2);
    });

    test('a rep is not counted until the lifter is back at the top', () {
      _feed(counter, [170, 120, 85, 120, 150]);
      expect(counter.repCount, 0);
      expect(counter.inRep, isTrue);
      _feed(counter, [165]);
      expect(counter.repCount, 1);
      expect(counter.inRep, isFalse);
    });

    test('reset clears counts and state', () {
      _feed(counter, _cleanSquat);
      counter.reset();
      expect(counter.repCount, 0);
      expect(counter.noRepCount, 0);
      expect(counter.inRep, isFalse);
    });
  });

  group('RepCounter — every launch lift', () {
    test('covers exactly the 8 launch lift keys', () {
      expect(RepCounter.launchLifts, unorderedEquals(_repPerLift.keys));
    });

    for (final entry in _repPerLift.entries) {
      test('${entry.key}: one clean rep counts once, three count three', () {
        final counter = RepCounter(liftKey: entry.key);
        expect(_feed(counter, entry.value), 1);
        _feed(counter, entry.value);
        _feed(counter, entry.value);
        expect(counter.repCount, 3);
        expect(counter.noRepCount, 0);
      });

      test('${entry.key}: PoseAnalyzer names the angle used for counting', () {
        expect(PoseAnalyzer.repAngleKey(entry.key), isNotNull);
      });
    }

    test('an unsupported lift key is rejected', () {
      expect(() => RepCounter(liftKey: 'bicep_curl'), throwsArgumentError);
      expect(PoseAnalyzer.repAngleKey('bicep_curl'), isNull);
    });
  });
}
