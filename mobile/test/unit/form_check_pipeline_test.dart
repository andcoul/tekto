import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/form_check/form_check_pipeline.dart';
import 'package:tekto/shared/services/form_check/pose_analyzer.dart';

// ---------------------------------------------------------------------------
// T068 — frame pipeline: rep tagging, flagged reps, rep-level cues, frame timing
// ---------------------------------------------------------------------------

FormFrameResult _squatFrame(double knee, {List<String> cues = const [], double confidence = 0.9}) =>
    FormFrameResult(activeCues: cues, repDetected: false, jointAngleSnapshot: {'knee_angle': knee}, confidence: confidence);

const _squat = <double>[170, 150, 120, 85, 100, 130, 165];

void main() {
  test('Quickstart Scenario 4: 5 squats, knee cave on reps 2 and 4', () {
    final pipeline = FormCheckPipeline(liftKey: 'squat');
    for (var rep = 1; rep <= 5; rep++) {
      for (final knee in _squat) {
        final caves = (rep == 2 || rep == 4) && knee < 130;
        pipeline.add(_squatFrame(knee, cues: caves ? ['knee_cave'] : const []));
      }
    }

    final summary = pipeline.finish(language: 'en');
    expect(summary.repCount, 5);
    expect(summary.flaggedReps, [2, 4]);
    expect(summary.cuesShown, ['knee_cave']);
    expect(summary.score, lessThan(100));
  });

  test('add returns the live cues and the running rep count', () {
    final pipeline = FormCheckPipeline(liftKey: 'squat');
    late FrameOutcome last;
    for (final knee in _squat.take(6)) {
      last = pipeline.add(_squatFrame(knee));
    }
    expect(last.repCount, 0);
    expect(last.repCompleted, isFalse);

    last = pipeline.add(_squatFrame(165, cues: ['knee_cave']));
    expect(last.repCompleted, isTrue);
    expect(last.repCount, 1);
    expect(last.cues.single.key, 'knee_cave');
  });

  test('the frame that completes a rep belongs to that rep', () {
    final pipeline = FormCheckPipeline(liftKey: 'squat');
    for (final knee in _squat.take(6)) {
      pipeline.add(_squatFrame(knee));
    }
    pipeline.add(_squatFrame(165, cues: ['knee_cave'])); // completes rep 1
    expect(pipeline.finish(language: 'en').flaggedReps, [1]);
  });

  test('a shallow squat is a no-rep and shows the depth cue', () {
    final pipeline = FormCheckPipeline(liftKey: 'squat');
    final outcomes = [for (final knee in const <double>[170, 140, 120, 145, 170]) pipeline.add(_squatFrame(knee))];

    expect(outcomes.any((o) => o.cues.any((c) => c.key == 'depth_too_shallow')), isTrue);
    final summary = pipeline.finish(language: 'en');
    expect(summary.repCount, 0);
    expect(summary.cuesShown, contains('depth_too_shallow'));
    expect(summary.flaggedReps, isEmpty); // not a counted rep
  });

  test('low confidence: cues suppressed but reps still counted (best effort)', () {
    final pipeline = FormCheckPipeline(liftKey: 'squat');
    late FrameOutcome last;
    for (final knee in _squat) {
      last = pipeline.add(_squatFrame(knee, cues: ['knee_cave'], confidence: 0.4));
    }
    expect(last.cues.single.key, 'adjust_lighting');
    final summary = pipeline.finish(language: 'en');
    expect(summary.repCount, 1);
    expect(summary.flaggedReps, isEmpty);
  });

  test('frames without the counting angle do not move the counter', () {
    final pipeline = FormCheckPipeline(liftKey: 'squat');
    pipeline.add(const FormFrameResult(activeCues: [], repDetected: false, jointAngleSnapshot: {}, confidence: 0.9));
    expect(pipeline.finish(language: 'en').repCount, 0);
  });

  test('median frame processing time (Performance Standards < 150 ms)', () {
    final pipeline = FormCheckPipeline(liftKey: 'squat');
    expect(pipeline.medianProcessingMs, isNull);
    for (final ms in [40, 200, 60, 50, 70]) {
      pipeline.add(_squatFrame(170), processing: Duration(milliseconds: ms));
    }
    expect(pipeline.medianProcessingMs, 60);
    expect(medianOf([1, 2, 3, 4]), 2.5);
  });

  test('unsupported lift is rejected up front', () {
    expect(() => FormCheckPipeline(liftKey: 'bicep_curl'), throwsArgumentError);
  });
}
