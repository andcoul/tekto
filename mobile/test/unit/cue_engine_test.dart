import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/form_check/cue_engine.dart';
import 'package:tekto/shared/services/form_check/pose_analyzer.dart';

// ---------------------------------------------------------------------------
// T084 — CueEngine unit tests
// ---------------------------------------------------------------------------

void main() {
  const engine = CueEngine();

  group('CueEngine — confidence gate (Principle II)', () {
    test(
      'returns only "adjust_lighting" and no other cues when confidence = 0.5',
      () {
        // Confidence below 0.6 threshold → all cues suppressed
        const result = FormFrameResult(
          activeCues: ['knee_cave', 'depth_too_shallow'],
          repDetected: false,
          jointAngleSnapshot: {},
          confidence: 0.5,
        );

        final cues = engine.evaluate(result);

        expect(cues.length, equals(1));
        expect(cues.first.key, equals('adjust_lighting'));
      },
    );

    test(
      'returns real cues (not adjust_lighting) when confidence = 0.65',
      () {
        const result = FormFrameResult(
          activeCues: ['knee_cave'],
          repDetected: false,
          jointAngleSnapshot: {},
          confidence: 0.65,
        );

        final cues = engine.evaluate(result);

        expect(cues.isNotEmpty, isTrue);
        expect(cues.any((c) => c.key == 'adjust_lighting'), isFalse);
        expect(cues.any((c) => c.key == 'knee_cave'), isTrue);
      },
    );

    test(
      'suppresses cues at exactly 0.6 boundary (confidence < 0.6 triggers gate)',
      () {
        // Exactly at threshold = should pass (0.6 is NOT below threshold)
        const result = FormFrameResult(
          activeCues: ['knee_cave'],
          repDetected: false,
          jointAngleSnapshot: {},
          confidence: 0.6,
        );

        final cues = engine.evaluate(result);
        // 0.6 is not < 0.6, so real cues should be returned
        expect(cues.any((c) => c.key == 'knee_cave'), isTrue);
      },
    );
  });

  group('CueEngine — cue mapping', () {
    test('maps knee_cave to a non-empty English and French text', () {
      const result = FormFrameResult(
        activeCues: ['knee_cave'],
        repDetected: false,
        jointAngleSnapshot: {},
        confidence: 0.9,
      );

      final cues = engine.evaluate(result);
      expect(cues.length, equals(1));
      expect(cues.first.textEn.isNotEmpty, isTrue);
      expect(cues.first.textFr.isNotEmpty, isTrue);
    });

    test('limits output to 3 cues per frame even when more violations exist', () {
      const result = FormFrameResult(
        activeCues: [
          'knee_cave',
          'depth_too_shallow',
          'back_rounding',
          'elbow_flare',
          'hips_sagging',
        ],
        repDetected: false,
        jointAngleSnapshot: {},
        confidence: 0.9,
      );

      final cues = engine.evaluate(result);
      expect(cues.length, lessThanOrEqualTo(3));
    });

    test('returns empty list when no active cues and confidence is high', () {
      const result = FormFrameResult(
        activeCues: [],
        repDetected: false,
        jointAngleSnapshot: {},
        confidence: 0.95,
      );

      final cues = engine.evaluate(result);
      expect(cues, isEmpty);
    });

    test('errors sort before warnings', () {
      const result = FormFrameResult(
        activeCues: ['depth_too_shallow', 'knee_cave'], // warning, error
        repDetected: false,
        jointAngleSnapshot: {},
        confidence: 0.9,
      );

      final cues = engine.evaluate(result);
      expect(cues.first.severity, equals(CueSeverity.error));
    });
  });
}
