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
  });

  final List<String> activeCues; // cue keys, e.g. 'knee_cave', 'back_round'
  final bool repDetected;
  final Map<String, double> jointAngleSnapshot; // angle name → degrees
  final double confidence;
}

// ---------------------------------------------------------------------------
// PoseAnalyzer
// ---------------------------------------------------------------------------

/// Analyses a single ML Kit [Pose] frame for the given [liftKey] and returns
/// a [FormFrameResult] with any detected technique violations.
///
/// Supported lift keys: squat, lunge, deadlift, romanian_deadlift,
///   bench_press, overhead_press, row, hip_thrust, push_up.
///
/// Principle II: frames are NEVER stored or transmitted.
class PoseAnalyzer {
  const PoseAnalyzer();

  FormFrameResult analyze(Pose pose, String liftKey) {
    final confidence = _overallConfidence(pose);
    final angles = _computeAngles(pose, liftKey);
    final cues = _detectViolations(angles, liftKey);

    final repDetected = _detectRep(angles, liftKey);

    return FormFrameResult(
      activeCues: cues,
      repDetected: repDetected,
      jointAngleSnapshot: angles,
      confidence: confidence,
    );
  }

  // ---------------------------------------------------------------------------
  // Confidence
  // ---------------------------------------------------------------------------

  static double _overallConfidence(Pose pose) {
    final landmarks = pose.landmarks.values;
    if (landmarks.isEmpty) return 0.0;
    final sum = landmarks.fold<double>(
        0.0, (acc, lm) => acc + (lm.likelihood ?? 0.0));
    return sum / landmarks.length;
  }

  // ---------------------------------------------------------------------------
  // Angle computation per lift
  // ---------------------------------------------------------------------------

  static Map<String, double> _computeAngles(Pose pose, String liftKey) {
    final lm = pose.landmarks;

    double? get(PoseLandmarkType type) =>
        lm[type]?.y; // simplified: use y-coordinate as proxy

    switch (liftKey) {
      case 'squat':
      case 'lunge':
        return {
          'knee_angle': _kneeAngle(pose),
          'hip_depth': _hipToKneeRatio(pose),
          'knee_cave': _kneeCaveAngle(pose),
        };
      case 'deadlift':
      case 'romanian_deadlift':
        return {
          'back_angle': _backAngle(pose),
          'hip_hinge': _hipHingeAngle(pose),
        };
      case 'bench_press':
        return {
          'elbow_flare': _elbowFlareAngle(pose),
          'wrist_symmetry': _wristSymmetry(pose),
        };
      case 'overhead_press':
        return {
          'elbow_lockout': _elbowAngle(pose, side: 'right'),
        };
      case 'row':
        return {
          'back_angle': _backAngle(pose),
          'elbow_pull': _elbowAngle(pose, side: 'right'),
        };
      case 'hip_thrust':
        return {
          'hip_extension': _hipExtensionAngle(pose),
        };
      case 'push_up':
        return {
          'elbow_angle': _elbowAngle(pose, side: 'right'),
          'body_alignment': _bodyAlignmentAngle(pose),
        };
      default:
        return {};
    }
  }

  // ---------------------------------------------------------------------------
  // Violation detection
  // ---------------------------------------------------------------------------

  static List<String> _detectViolations(
      Map<String, double> angles, String liftKey) {
    final cues = <String>[];

    switch (liftKey) {
      case 'squat':
      case 'lunge':
        if ((angles['knee_cave'] ?? 0) > 15) cues.add('knee_cave');
        if ((angles['hip_depth'] ?? 1) > 0.9) cues.add('depth_too_shallow');
        break;
      case 'deadlift':
      case 'romanian_deadlift':
        if ((angles['back_angle'] ?? 0) > 30) cues.add('back_rounding');
        break;
      case 'bench_press':
        if ((angles['elbow_flare'] ?? 0) > 75) cues.add('elbow_flare');
        break;
      case 'overhead_press':
        if ((angles['elbow_lockout'] ?? 180) < 160) cues.add('incomplete_lockout');
        break;
      case 'push_up':
        if ((angles['body_alignment'] ?? 0) > 15) cues.add('hips_sagging');
        break;
    }

    return cues;
  }

  // ---------------------------------------------------------------------------
  // Rep detection (simplified phase-based)
  // ---------------------------------------------------------------------------

  static bool _detectRep(Map<String, double> angles, String liftKey) {
    // Simplified: detect rep when knee angle < 90° (bottom of squat/lunge)
    // RepCounter owns the full state machine; PoseAnalyzer just flags phase.
    switch (liftKey) {
      case 'squat':
      case 'lunge':
        return (angles['knee_angle'] ?? 180) < 95;
      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Angle computation helpers (simplified geometry from landmark positions)
  // ---------------------------------------------------------------------------

  static double _kneeAngle(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (hip == null || knee == null || ankle == null) return 180;
    return _angleBetweenPoints(hip.x, hip.y, knee.x, knee.y, ankle.x, ankle.y);
  }

  static double _hipToKneeRatio(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    if (hip == null || knee == null) return 0.5;
    // Ratio < 1.0 means hip is lower than knee (deep squat)
    return (hip.y / knee.y).clamp(0.0, 2.0);
  }

  static double _kneeCaveAngle(Pose pose) {
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (hip == null || knee == null || ankle == null) return 0;
    // Lateral deviation of knee from hip-ankle line
    final expected = (hip.x + ankle.x) / 2;
    return (knee.x - expected).abs();
  }

  static double _backAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    if (shoulder == null || hip == null) return 0;
    final dy = shoulder.y - hip.y;
    final dx = shoulder.x - hip.x;
    return _toDegrees(dx.abs() / (dy.abs() + 0.001));
  }

  static double _hipHingeAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    if (shoulder == null || hip == null || knee == null) return 180;
    return _angleBetweenPoints(
        shoulder.x, shoulder.y, hip.x, hip.y, knee.x, knee.y);
  }

  static double _elbowFlareAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.rightElbow];
    if (shoulder == null || elbow == null) return 0;
    final dx = (elbow.x - shoulder.x).abs();
    final dy = (elbow.y - shoulder.y).abs();
    return _toDegrees(dx / (dy + 0.001));
  }

  static double _wristSymmetry(Pose pose) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    if (leftWrist == null || rightWrist == null) return 0;
    return (leftWrist.y - rightWrist.y).abs();
  }

  static double _elbowAngle(Pose pose, {required String side}) {
    final shoulder = side == 'right'
        ? pose.landmarks[PoseLandmarkType.rightShoulder]
        : pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = side == 'right'
        ? pose.landmarks[PoseLandmarkType.rightElbow]
        : pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = side == 'right'
        ? pose.landmarks[PoseLandmarkType.rightWrist]
        : pose.landmarks[PoseLandmarkType.leftWrist];
    if (shoulder == null || elbow == null || wrist == null) return 180;
    return _angleBetweenPoints(
        shoulder.x, shoulder.y, elbow.x, elbow.y, wrist.x, wrist.y);
  }

  static double _hipExtensionAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final knee = pose.landmarks[PoseLandmarkType.leftKnee];
    if (shoulder == null || hip == null || knee == null) return 0;
    return _angleBetweenPoints(
        shoulder.x, shoulder.y, hip.x, hip.y, knee.x, knee.y);
  }

  static double _bodyAlignmentAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final hip = pose.landmarks[PoseLandmarkType.leftHip];
    final ankle = pose.landmarks[PoseLandmarkType.leftAnkle];
    if (shoulder == null || hip == null || ankle == null) return 0;
    // Deviation of hip from shoulder-ankle line
    final expectedY =
        shoulder.y + (ankle.y - shoulder.y) * 0.5; // midpoint
    return (hip.y - expectedY).abs();
  }

  // ---------------------------------------------------------------------------
  // Geometry utilities
  // ---------------------------------------------------------------------------

  static double _angleBetweenPoints(
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
  ) {
    final ba = [ax - bx, ay - by];
    final bc = [cx - bx, cy - by];
    final dot = ba[0] * bc[0] + ba[1] * bc[1];
    final magBa = _magnitude(ba);
    final magBc = _magnitude(bc);
    if (magBa == 0 || magBc == 0) return 180;
    final cosTheta = (dot / (magBa * magBc)).clamp(-1.0, 1.0);
    return _toDegrees(_acos(cosTheta));
  }

  static double _magnitude(List<double> v) =>
      (v[0] * v[0] + v[1] * v[1]).abs() < 1e-10
          ? 0
          : (v[0] * v[0] + v[1] * v[1]).sqrt();

  static double _acos(double x) => _mathAcos(x);
  static double _toDegrees(double radians) => radians * 180 / 3.141592653589793;
}

// Dart doesn't expose dart:math here without import; using extension
extension _Sqrt on double {
  double sqrt() {
    if (this < 0) return 0;
    double x = this;
    double z = x / 2;
    for (int i = 0; i < 50; i++) {
      z -= (z * z - x) / (2 * z);
    }
    return z;
  }
}

double _mathAcos(double x) {
  // Taylor approximation for acos
  x = x.clamp(-1.0, 1.0);
  if (x >= 1.0) return 0;
  if (x <= -1.0) return 3.141592653589793;
  return 3.141592653589793 / 2 - _mathAsin(x);
}

double _mathAsin(double x) {
  double result = x;
  double term = x;
  final x2 = x * x;
  for (int n = 1; n < 10; n++) {
    term *= x2 * (2 * n - 1) * (2 * n - 1) / (2 * n * (2 * n + 1));
    result += term;
  }
  return result;
}
