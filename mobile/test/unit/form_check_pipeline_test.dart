import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/shared/services/form_check/cue_engine.dart';
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

  // -------------------------------------------------------------------------
  // T129 — top-of-rep cues: overhead press lockout, hip thrust extension (FR-022/023/024)
  // -------------------------------------------------------------------------

  group('overhead press lockout', () {
    // Elbow angle, starting locked out: down to the rack position and pressed back up.
    const clean = <double>[175, 140, 100, 85, 110, 145, 175];

    test('quickstart: 5 clean reps + 1 press stopped short → 5 reps, lockout cue fires', () {
      final pipeline = FormCheckPipeline(liftKey: 'overhead_press');
      final outcomes = <FrameOutcome>[];
      for (var rep = 0; rep < 5; rep++) {
        outcomes.addAll(clean.map((e) => pipeline.add(_frame('elbow_angle', e))));
      }
      // Partial: pressed to 140° only, then back down to the rack.
      outcomes.addAll(const <double>[140, 100, 85, 110, 140, 120, 90].map((e) => pipeline.add(_frame('elbow_angle', e))));

      expect(outcomes.where(_shows('incomplete_lockout')), isNotEmpty);
      final summary = pipeline.finish(language: 'en');
      expect(summary.repCount, 5);
      expect(summary.cuesShown, contains('incomplete_lockout'));
      expect(summary.flaggedReps, isEmpty); // the short press was not a counted rep
    });

    test('a counted rep that stops short of full lockout is flagged', () {
      final pipeline = FormCheckPipeline(liftKey: 'overhead_press');
      for (final e in clean) {
        pipeline.add(_frame('elbow_angle', e)); // rep 1, full lockout
      }
      // Rep 2 reaches the counting threshold (155°) but tops out at 160° before lowering again.
      for (final e in const <double>[140, 100, 85, 120, 158, 160, 140, 100]) {
        pipeline.add(_frame('elbow_angle', e));
      }
      final summary = pipeline.finish(language: 'en');
      expect(summary.repCount, 2);
      expect(summary.flaggedReps, [2]);
      expect(summary.cuesShown, ['incomplete_lockout']);
    });

    test('clean reps never show the lockout cue', () {
      final pipeline = FormCheckPipeline(liftKey: 'overhead_press');
      final outcomes = [
        for (var rep = 0; rep < 3; rep++) ...clean.map((e) => pipeline.add(_frame('elbow_angle', e))),
      ];
      expect(outcomes.where(_shows('incomplete_lockout')), isEmpty);
      expect(pipeline.finish(language: 'en').repCount, 3);
    });

    test('jitter at the bottom is not judged as a short press', () {
      final pipeline = FormCheckPipeline(liftKey: 'overhead_press');
      final outcomes = [
        for (final e in const <double>[175, 120, 88, 100, 86, 98, 85, 130, 175]) pipeline.add(_frame('elbow_angle', e)),
      ];
      expect(outcomes.where(_shows('incomplete_lockout')), isEmpty);
      expect(pipeline.finish(language: 'en').repCount, 1);
    });

    test('a set that starts in the rack position counts the first press', () {
      final pipeline = FormCheckPipeline(liftKey: 'overhead_press');
      final outcomes = [for (final e in const <double>[85, 120, 175]) pipeline.add(_frame('elbow_angle', e))];
      expect(outcomes.last.repCompleted, isTrue);
      expect(outcomes.where(_shows('incomplete_lockout')), isEmpty);
    });
  });

  group('hip thrust extension', () {
    // Hip angle, starting at full extension: down to the floor and driven back up.
    const clean = <double>[175, 150, 120, 98, 130, 160, 176];

    test('quickstart: 5 clean reps + 1 thrust stopped short → 5 reps, extension cue fires', () {
      final pipeline = FormCheckPipeline(liftKey: 'hip_thrust');
      final outcomes = <FrameOutcome>[];
      for (var rep = 0; rep < 5; rep++) {
        outcomes.addAll(clean.map((e) => pipeline.add(_frame('hip_angle', e))));
      }
      // Partial: hips driven to 155° only, then lowered.
      outcomes.addAll(const <double>[150, 120, 98, 130, 155, 135, 100].map((e) => pipeline.add(_frame('hip_angle', e))));

      expect(outcomes.where(_shows('incomplete_hip_extension')), isNotEmpty);
      final summary = pipeline.finish(language: 'fr');
      expect(summary.repCount, 5);
      expect(summary.cuesShown, contains('incomplete_hip_extension'));
    });

    test('clean reps never show the extension cue', () {
      final pipeline = FormCheckPipeline(liftKey: 'hip_thrust');
      final outcomes = [
        for (var rep = 0; rep < 3; rep++) ...clean.map((e) => pipeline.add(_frame('hip_angle', e))),
      ];
      expect(outcomes.where(_shows('incomplete_hip_extension')), isEmpty);
      expect(pipeline.finish(language: 'en').repCount, 3);
    });
  });

  test('every launch lift has at least one live cue the engine can show (FR-022)', () {
    const engine = CueEngine();
    for (final key in ['incomplete_lockout', 'incomplete_hip_extension']) {
      final cue = engine.cueFor(key);
      expect(cue, isNotNull, reason: key);
      expect(cue!.textEn, isNotEmpty);
      expect(cue.textFr, isNotEmpty);
    }
  });
}

FormFrameResult _frame(String angleKey, double degrees) =>
    FormFrameResult(activeCues: const [], repDetected: false, jointAngleSnapshot: {angleKey: degrees}, confidence: 0.9);

bool Function(FrameOutcome) _shows(String cueKey) => (o) => o.cues.any((c) => c.key == cueKey);
