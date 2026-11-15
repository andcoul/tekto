import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// ---------------------------------------------------------------------------
// Output types
// ---------------------------------------------------------------------------

class FormFrameResult {
  const FormFrameResult({
    required this.activeCues,
    required this.repDetected,
    required this.jointAngleSnapshot,
    required this.confidence,
    this.repIndex = 0,
  });

  final List<String> activeCues; // cue keys, e.g. 'knee_cave', 'back_rounding'

  /// True on the frame where [RepCounter] completed a rep.
  final bool repDetected;
  final Map<String, double> jointAngleSnapshot; // angle name → degrees (or a normalized ratio)
  final double confidence;

  /// 1-based rep this frame belongs to; 0 when standing between reps (FR-024 flagged reps).
  final int repIndex;

  FormFrameResult copyWith({List<String>? activeCues, bool? repDetected, int? repIndex}) => FormFrameResult(
        activeCues: activeCues ?? this.activeCues,
        repDetected: repDetected ?? this.repDetected,
        jointAngleSnapshot: jointAngleSnapshot,
        confidence: confidence,
        repIndex: repIndex ?? this.repIndex,
      );
}

// ---------------------------------------------------------------------------
// PoseAnalyzer
// ---------------------------------------------------------------------------

/// Turns one ML Kit [Pose] into joint angles and per-frame technique violations for a launch
/// lift. Rep counting and rep-level checks (depth, lockout) live in [FormCheckPipeline].
///
/// Geometry is 2D image coordinates (y grows downward). Distances are divided by a body
/// segment length so thresholds do not depend on camera resolution or distance.
/// Thresholds are first estimates and are tuned on device (quickstart Scenario 4).
///
/// Principle II: frames are never stored or transmitted; only the numbers below are kept.
class PoseAnalyzer {
  const PoseAnalyzer();

  /// Landmarks below this likelihood are treated as not visible.
  static const minLandmarkLikelihood = 0.5;

  /// Knee drifting toward the midline by more than this share of leg length.
  static const kneeCaveRatio = 0.08;

  /// Hips below the shoulder–ankle line by more than this share of body length.
  static const hipSagRatio = 0.06;

  /// Upper arm more than this many degrees away from the torso at the bottom of a press.
  static const elbowFlareDegrees = 75.0;

  /// Head and upper back folding forward from the hip–shoulder line by more than this.
  static const backRoundingDegrees = 40.0;

  /// The angle [RepCounter] counts for [liftKey]; null when the lift is not supported.
  static String? repAngleKey(String liftKey) => switch (liftKey) {
        'squat' || 'lunge' => 'knee_angle',
        'deadlift' || 'hip_thrust' => 'hip_angle',
        'bench_press' || 'overhead_press' || 'row' || 'push_up' => 'elbow_angle',
        _ => null,
      };

  FormFrameResult analyze(Pose pose, String liftKey) {
    final p = _PoseView(pose);
    final angles = <String, double>{};
    final cues = <String>[];

    switch (liftKey) {
      case 'squat':
      case 'lunge':
        // Lunge: the front knee is the more bent one; squat: the clearer side.
        final knee = liftKey == 'lunge' ? p.minAngle(_kneeJoints) : p.bestAngle(_kneeJoints);
        if (knee != null) angles['knee_angle'] = knee;
        final cave = p.kneeCave();
        if (cave != null) {
          angles['knee_cave'] = cave;
          // Only under load: standing knees are not judged.
          if (cave > kneeCaveRatio && (knee ?? 180) < 150) cues.add('knee_cave');
        }
      case 'deadlift':
      case 'row':
        final hip = p.bestAngle(_hipJoints);
        if (hip != null) angles['hip_angle'] = hip;
        if (liftKey == 'row') {
          final elbow = p.bestAngle(_elbowJoints);
          if (elbow != null) angles['elbow_angle'] = elbow;
        }
        final rounding = p.backRounding();
        if (rounding != null) {
          angles['back_rounding'] = rounding;
          if (rounding > backRoundingDegrees && (hip ?? 180) < 150) cues.add('back_rounding');
        }
      case 'hip_thrust':
        final hip = p.bestAngle(_hipJoints);
        if (hip != null) angles['hip_angle'] = hip;
      case 'bench_press':
      case 'overhead_press':
        final elbow = p.bestAngle(_elbowJoints);
        if (elbow != null) angles['elbow_angle'] = elbow;
        if (liftKey == 'bench_press') {
          final shoulder = p.bestAngle(_shoulderJoints);
          if (shoulder != null) {
            angles['shoulder_angle'] = shoulder;
            if (shoulder > elbowFlareDegrees && (elbow ?? 180) < 120) cues.add('elbow_flare');
          }
        }
      case 'push_up':
        final elbow = p.bestAngle(_elbowJoints);
        if (elbow != null) angles['elbow_angle'] = elbow;
        final sag = p.hipSag();
        if (sag != null) {
          angles['hip_sag'] = sag;
          if (sag > hipSagRatio) cues.add('hips_sagging');
        }
    }

    return FormFrameResult(
      activeCues: cues,
      repDetected: false,
      jointAngleSnapshot: angles,
      confidence: p.confidence(_landmarksFor(liftKey)),
    );
  }

  static List<PoseLandmarkType> _landmarksFor(String liftKey) => switch (liftKey) {
        'squat' || 'lunge' => _legs,
        'bench_press' || 'overhead_press' => _arms,
        _ => [..._arms, ..._legs],
      };
}

// ---------------------------------------------------------------------------
// Geometry over one pose
// ---------------------------------------------------------------------------

typedef _Joint = (PoseLandmarkType, PoseLandmarkType, PoseLandmarkType);

const _kneeJoints = [
  (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
  (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
];
const _hipJoints = [
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
];
const _elbowJoints = [
  (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
  (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
];
const _shoulderJoints = [
  (PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
  (PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
];
const _legs = [
  PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, PoseLandmarkType.leftKnee, //
  PoseLandmarkType.rightKnee, PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle,
];
const _arms = [
  PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, PoseLandmarkType.leftElbow, //
  PoseLandmarkType.rightElbow, PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist,
];

class _PoseView {
  _PoseView(this.pose);
  final Pose pose;

  PoseLandmark? _visible(PoseLandmarkType t) {
    final lm = pose.landmarks[t];
    return lm != null && lm.likelihood >= PoseAnalyzer.minLandmarkLikelihood ? lm : null;
  }

  /// Mean likelihood of the landmarks this lift depends on (missing ones count as 0).
  double confidence(List<PoseLandmarkType> types) {
    if (types.isEmpty) return 0;
    final sum = types.fold<double>(0, (acc, t) => acc + (pose.landmarks[t]?.likelihood ?? 0));
    return sum / types.length;
  }

  ({double angle, double likelihood})? _angle(_Joint j) {
    final a = _visible(j.$1), b = _visible(j.$2), c = _visible(j.$3);
    if (a == null || b == null || c == null) return null;
    return (angle: angleAt(a, b, c), likelihood: a.likelihood + b.likelihood + c.likelihood);
  }

  /// Angle on the side the camera sees best.
  double? bestAngle(List<_Joint> joints) {
    final found = joints.map(_angle).whereType<({double angle, double likelihood})>().toList();
    if (found.isEmpty) return null;
    found.sort((x, y) => y.likelihood.compareTo(x.likelihood));
    return found.first.angle;
  }

  /// Smallest visible angle (the more bent side).
  double? minAngle(List<_Joint> joints) {
    final found = joints.map(_angle).whereType<({double angle, double likelihood})>().map((r) => r.angle);
    return found.isEmpty ? null : found.reduce(math.min);
  }

  /// Front view: how far the knees drift toward the midline from the hip–ankle line, as a
  /// share of leg length. Worst leg; negative means knees pushed out (good).
  double? kneeCave() {
    final lh = _visible(PoseLandmarkType.leftHip), rh = _visible(PoseLandmarkType.rightHip);
    if (lh == null || rh == null) return null;
    final midX = (lh.x + rh.x) / 2;
    double? worst;
    for (final (hip, kneeT, ankleT) in [
      (lh, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
      (rh, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
    ]) {
      final knee = _visible(kneeT), ankle = _visible(ankleT);
      if (knee == null || ankle == null) continue;
      final legLength = _dist(hip, ankle);
      if (legLength == 0) continue;
      // x of the hip–ankle line at the knee's height.
      final t = (ankle.y - hip.y).abs() < 1e-6 ? 0.5 : (knee.y - hip.y) / (ankle.y - hip.y);
      final lineX = hip.x + (ankle.x - hip.x) * t;
      final towardMidline = midX >= lineX ? 1 : -1;
      final inward = (knee.x - lineX) * towardMidline / legLength;
      worst = worst == null ? inward : math.max(worst, inward);
    }
    return worst;
  }

  /// Side view: hips below the shoulder–ankle line, as a share of body length.
  double? hipSag() {
    for (final side in [
      (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, PoseLandmarkType.leftAnkle),
      (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, PoseLandmarkType.rightAnkle),
    ]) {
      final s = _visible(side.$1), h = _visible(side.$2), a = _visible(side.$3);
      if (s == null || h == null || a == null) continue;
      final length = _dist(s, a);
      if (length == 0) continue;
      // Signed distance of the hip from the line; positive = below it (larger y) in image space.
      final cross = (a.x - s.x) * (h.y - s.y) - (a.y - s.y) * (h.x - s.x);
      final below = (a.x >= s.x ? cross : -cross) / length;
      return below / length;
    }
    return null;
  }

  /// Side view: angle between the hip→shoulder line and the shoulder→ear line. A neutral
  /// spine keeps them close to straight; folding the head and upper back forward bends it.
  /// 2D landmarks have no mid-spine point, so this is a proxy for upper-back rounding.
  double? backRounding() {
    for (final side in [
      (PoseLandmarkType.leftHip, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftEar),
      (PoseLandmarkType.rightHip, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightEar),
    ]) {
      final h = _visible(side.$1), s = _visible(side.$2), e = _visible(side.$3);
      if (h == null || s == null || e == null) continue;
      return 180 - angleAt(h, s, e);
    }
    return null;
  }
}

/// Angle ABC in degrees (0–180) at point [b].
double angleAt(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
  final v1x = a.x - b.x, v1y = a.y - b.y, v2x = c.x - b.x, v2y = c.y - b.y;
  final m1 = math.sqrt(v1x * v1x + v1y * v1y), m2 = math.sqrt(v2x * v2x + v2y * v2y);
  if (m1 == 0 || m2 == 0) return 180;
  final cos = ((v1x * v2x + v1y * v2y) / (m1 * m2)).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

double _dist(PoseLandmark a, PoseLandmark b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
