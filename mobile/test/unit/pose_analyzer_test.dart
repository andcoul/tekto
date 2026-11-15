import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:tekto/shared/services/form_check/pose_analyzer.dart';

// ---------------------------------------------------------------------------
// T062 — PoseAnalyzer geometry (image coordinates, y grows downward)
// ---------------------------------------------------------------------------

Pose _pose(Map<PoseLandmarkType, (double, double)> points, {double likelihood = 0.95}) => Pose(landmarks: {
      for (final e in points.entries)
        e.key: PoseLandmark(type: e.key, x: e.value.$1, y: e.value.$2, z: 0, likelihood: likelihood),
    });

/// Front view of both legs; [kneeShift] moves each knee toward the midline (+) or out (−).
Pose _frontLegs({required double kneeShift, double kneeY = 300}) => _pose({
      PoseLandmarkType.leftHip: (180, 200),
      PoseLandmarkType.rightHip: (120, 200),
      PoseLandmarkType.leftKnee: (180 - kneeShift, kneeY),
      PoseLandmarkType.rightKnee: (120 + kneeShift, kneeY),
      PoseLandmarkType.leftAnkle: (180, 400),
      PoseLandmarkType.rightAnkle: (120, 400),
    });

void main() {
  const analyzer = PoseAnalyzer();

  test('angleAt: straight line is 180°, right angle is 90°', () {
    PoseLandmark p(double x, double y) =>
        PoseLandmark(type: PoseLandmarkType.leftKnee, x: x, y: y, z: 0, likelihood: 1);
    expect(angleAt(p(0, 0), p(0, 10), p(0, 20)), closeTo(180, 0.01));
    expect(angleAt(p(0, 0), p(0, 10), p(10, 10)), closeTo(90, 0.01));
    expect(angleAt(p(10, 0), p(0, 0), p(10, 10)), closeTo(45, 0.01));
  });

  test('squat side view: knee angle at parallel is about 90°', () {
    final pose = _pose({
      PoseLandmarkType.leftHip: (100, 300),
      PoseLandmarkType.leftKnee: (200, 300),
      PoseLandmarkType.leftAnkle: (200, 400),
    });
    final r = analyzer.analyze(pose, 'squat');
    expect(r.jointAngleSnapshot['knee_angle'], closeTo(90, 0.5));
  });

  group('knee cave (front view)', () {
    test('knees drifting toward the midline under load → knee_cave', () {
      // Knees bent: knee higher than the straight-leg midpoint is irrelevant in front view, so the
      // knee angle comes from the inward shift itself; use a big shift to bend below 150°.
      final r = analyzer.analyze(_frontLegs(kneeShift: 40, kneeY: 260), 'squat');
      expect(r.jointAngleSnapshot['knee_cave'], greaterThan(PoseAnalyzer.kneeCaveRatio));
      expect(r.activeCues, contains('knee_cave'));
    });

    test('knees pushed out are not knee cave', () {
      final r = analyzer.analyze(_frontLegs(kneeShift: -40, kneeY: 260), 'squat');
      expect(r.jointAngleSnapshot['knee_cave'], lessThan(0));
      expect(r.activeCues, isNot(contains('knee_cave')));
    });

    test('knees over the feet are not knee cave', () {
      final r = analyzer.analyze(_frontLegs(kneeShift: 0), 'squat');
      expect(r.activeCues, isEmpty);
    });
  });

  group('push-up hip sag (side view)', () {
    Pose plank(double hipY) => _pose({
          PoseLandmarkType.leftShoulder: (100, 200),
          PoseLandmarkType.leftHip: (250, hipY),
          PoseLandmarkType.leftAnkle: (400, 200),
          PoseLandmarkType.leftElbow: (100, 250),
          PoseLandmarkType.leftWrist: (100, 300),
        });

    test('hips below the shoulder–ankle line → hips_sagging', () {
      expect(analyzer.analyze(plank(240), 'push_up').activeCues, contains('hips_sagging'));
    });

    test('straight plank and piked hips are not sagging', () {
      expect(analyzer.analyze(plank(202), 'push_up').activeCues, isEmpty);
      expect(analyzer.analyze(plank(150), 'push_up').activeCues, isEmpty);
    });
  });

  group('deadlift back rounding (side view)', () {
    Pose hinge({required (double, double) ear}) => _pose({
          PoseLandmarkType.leftShoulder: (200, 200),
          PoseLandmarkType.leftHip: (100, 250),
          PoseLandmarkType.leftKnee: (130, 350),
          PoseLandmarkType.leftEar: ear,
        });

    test('head and shoulders in line with the hips is a neutral back', () {
      // Hip → shoulder continues straight on to the ear.
      final r = analyzer.analyze(hinge(ear: (240, 180)), 'deadlift');
      expect(r.jointAngleSnapshot['back_rounding'], lessThan(5));
      expect(r.activeCues, isEmpty);
    });

    test('head and upper back folding down toward the floor → back_rounding', () {
      final r = analyzer.analyze(hinge(ear: (215, 245)), 'deadlift');
      expect(r.activeCues, contains('back_rounding'));
    });

    test('a forward lean alone is not rounding', () {
      // Torso at ~27° from horizontal with a neutral neck: normal for a deadlift.
      final r = analyzer.analyze(hinge(ear: (240, 180)), 'deadlift');
      expect(r.jointAngleSnapshot['hip_angle'], lessThan(150));
      expect(r.activeCues, isNot(contains('back_rounding')));
    });
  });

  test('confidence only counts the landmarks the lift needs', () {
    final legsOnly = _frontLegs(kneeShift: 0); // no arm landmarks at all
    expect(analyzer.analyze(legsOnly, 'squat').confidence, closeTo(0.95, 1e-9));
    expect(analyzer.analyze(legsOnly, 'bench_press').confidence, 0);
  });

  test('low-likelihood landmarks are ignored', () {
    final pose = _pose({
      PoseLandmarkType.leftHip: (100, 300),
      PoseLandmarkType.leftKnee: (200, 300),
      PoseLandmarkType.leftAnkle: (200, 400),
    }, likelihood: 0.3);
    expect(analyzer.analyze(pose, 'squat').jointAngleSnapshot['knee_angle'], isNull);
  });
}
