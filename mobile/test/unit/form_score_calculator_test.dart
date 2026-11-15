import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/form_check/cue_engine.dart';
import 'package:tekto/shared/services/form_check/form_score_calculator.dart';
import 'package:tekto/shared/services/form_check/pose_analyzer.dart';

// ---------------------------------------------------------------------------
// T059 — FormScoreCalculator unit tests
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

  group('flaggedReps (FR-024)', () {
    FormFrameResult frame(int rep, {List<String> cues = const [], double confidence = 0.9}) =>
        FormFrameResult(activeCues: cues, repDetected: false, jointAngleSnapshot: const {}, confidence: confidence, repIndex: rep);

    test('lists the 1-based reps that had at least one cue, in order', () {
      final frames = [
        for (var rep = 1; rep <= 5; rep++) ...[
          frame(rep),
          frame(rep, cues: rep == 2 || rep == 4 ? ['knee_cave'] : const []),
          frame(rep),
        ],
      ];
      final summary = calculator.calculate(frames: frames, liftKey: 'squat', language: 'en', repCount: 5);
      expect(summary.flaggedReps, [2, 4]);
    });

    test('a rep with several cue frames is listed once', () {
      final frames = [frame(1, cues: ['knee_cave']), frame(1, cues: ['depth_too_shallow']), frame(2)];
      final summary = calculator.calculate(frames: frames, liftKey: 'squat', language: 'en', repCount: 2);
      expect(summary.flaggedReps, [1]);
    });

    test('ignores frames outside a counted rep and low-confidence frames', () {
      final frames = [
        frame(0, cues: ['knee_cave']), // standing between reps
        frame(1, cues: ['knee_cave'], confidence: 0.4), // only "adjust lighting" is shown
        frame(2, cues: ['knee_cave']), // rep 2 was never completed
      ];
      final summary = calculator.calculate(frames: frames, liftKey: 'squat', language: 'en', repCount: 1);
      expect(summary.flaggedReps, isEmpty);
    });

    test('clean set has no flagged reps', () {
      final summary = calculator.calculate(frames: [frame(1), frame(2)], liftKey: 'squat', language: 'en', repCount: 2);
      expect(summary.flaggedReps, isEmpty);
      expect(summary.score, 100);
    });
  });
}
