import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/form_check/cue_engine.dart';
import 'package:tekto/shared/services/form_check/form_score_calculator.dart';
import 'package:tekto/shared/services/form_check/pose_analyzer.dart';

// ---------------------------------------------------------------------------
// T083 — FormScoreCalculator unit tests
// ---------------------------------------------------------------------------

void main() {
  late FormScoreCalculator calculator;
  const engine = CueEngine();

  setUp(() {
    calculator = const FormScoreCalculator(cueEngine: engine);
  });

  test('returns score = 100 for a list with zero violations', () {
    // All frames have no active cues (perfect form)
    final frames = List.generate(
      10,
      (_) => const FormFrameResult(
        activeCues: [],
        repDetected: false,
        jointAngleSnapshot: {},
        confidence: 0.9,
      ),
    );

    final summary = calculator.calculate(
      frames: frames,
      liftKey: 'squat',
      language: 'en',
      repCount: 5,
    );

    expect(summary.score, equals(100));
  });

  test('returns score = 0 for a list where every frame has a violation', () {
    final frames = List.generate(
      10,
      (_) => const FormFrameResult(
        activeCues: ['knee_cave'],
        repDetected: false,
        jointAngleSnapshot: {},
        confidence: 0.9,
      ),
    );

    final summary = calculator.calculate(
      frames: frames,
      liftKey: 'squat',
      language: 'en',
      repCount: 3,
    );

    expect(summary.score, equals(0));
    expect(summary.repCount, equals(3));
  });

  test('topTip matches the most frequently occurring cue', () {
    // 7 frames with knee_cave, 3 with depth_too_shallow
    final frames = [
      ...List.generate(
        7,
        (_) => const FormFrameResult(
          activeCues: ['knee_cave'],
          repDetected: false,
          jointAngleSnapshot: {},
          confidence: 0.9,
        ),
      ),
      ...List.generate(
        3,
        (_) => const FormFrameResult(
          activeCues: ['depth_too_shallow'],
          repDetected: false,
          jointAngleSnapshot: {},
          confidence: 0.9,
        ),
      ),
    ];

    final summary = calculator.calculate(
      frames: frames,
      liftKey: 'squat',
      language: 'en',
      repCount: 5,
    );

    // topTip should come from knee_cave (most frequent)
    expect(summary.topTipEn, contains('knees'));
    expect(summary.cuesShown, containsAll(['knee_cave', 'depth_too_shallow']));
  });

  test('returns score = 100 and empty topTip for empty frame list', () {
    final summary = calculator.calculate(
      frames: [],
      liftKey: 'squat',
      language: 'en',
      repCount: 0,
    );

    expect(summary.score, equals(100));
    expect(summary.repCount, equals(0));
  });

  test('score is between 0 and 100 for mixed frame list', () {
    // 5 clean, 5 violated
    final frames = [
      ...List.generate(
        5,
        (_) => const FormFrameResult(
          activeCues: [],
          repDetected: false,
          jointAngleSnapshot: {},
          confidence: 0.9,
        ),
      ),
      ...List.generate(
        5,
        (_) => const FormFrameResult(
          activeCues: ['knee_cave'],
          repDetected: false,
          jointAngleSnapshot: {},
          confidence: 0.9,
        ),
      ),
    ];

    final summary = calculator.calculate(
      frames: frames,
      liftKey: 'squat',
      language: 'en',
      repCount: 2,
    );

    expect(summary.score, inInclusiveRange(0, 100));
    expect(summary.score, equals(50));
  });
}
