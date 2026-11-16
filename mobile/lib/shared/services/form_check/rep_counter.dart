/// Counts reps for one launch lift from the joint angle [PoseAnalyzer.repAngleKey] names.
///
/// Every launch lift is a cycle between an open angle (standing, arms locked, hips extended)
/// and a closed angle (bottom of the squat, bar on the chest, hips hinged). A rep is counted
/// when the angle has reached the bottom threshold and comes back to the top threshold.
///
///   top ──descendStart──▶ descending ──bottomThreshold──▶ bottom ──topThreshold──▶ rep ✓
///                              │
///                              └─ rises [reversalMargin]° above its lowest point before
///                                 reaching the bottom → no-rep; wait for the top again
///
/// Direction comes from the lowest angle seen in the current descent, not from fixed angles,
/// so jitter of a few degrees does not end a rep. Lifts that start at the bottom (overhead
/// press from the rack, deadlift from the floor) work too: the first press up counts once.
///
/// Principle V: unit tested (rep_counter_test.dart).
class RepCounter {
  RepCounter({required this.liftKey}) : _thresholds = _thresholdsFor(liftKey);

  /// The 8 launch lifts (FR-022).
  static const launchLifts = {
    'squat', 'deadlift', 'bench_press', 'overhead_press', 'row', 'lunge', 'hip_thrust', 'push_up', //
  };

  /// Degrees the angle must rise above its lowest point to count as turning back up.
  static const reversalMargin = 10.0;

  final String liftKey;
  final LiftThresholds _thresholds;

  _RepState _state = _RepState.top;
  double _lowest = double.infinity;
  int _repCount = 0;
  int _noRepCount = 0;

  int get repCount => _repCount;
  int get noRepCount => _noRepCount;
  LiftThresholds get thresholds => _thresholds;

  /// True between leaving the top and finishing the rep (frames here belong to rep
  /// `repCount + 1`); false while standing at the top or recovering from a no-rep.
  bool get inRep => _state == _RepState.descending || _state == _RepState.bottom;

  /// True once the current rep has reached full depth and until it is completed.
  bool get atBottom => _state == _RepState.bottom;

  /// Feeds one joint-angle measurement in degrees. Returns true when a rep was just completed.
  bool update(double angle) {
    switch (_state) {
      case _RepState.top:
        if (angle < _thresholds.descendStart) {
          _state = _RepState.descending;
          _lowest = angle;
          _checkBottom(angle);
        }
        return false;

      case _RepState.descending:
        if (angle < _lowest) _lowest = angle;
        if (_checkBottom(angle)) return false;
        if (angle >= _lowest + reversalMargin) {
          _noRepCount++; // turned back up before reaching depth
          _state = _RepState.recovering;
        }
        return false;

      case _RepState.bottom:
        if (angle >= _thresholds.topThreshold) {
          _repCount++;
          _state = _RepState.top;
          return true;
        }
        return false;

      case _RepState.recovering:
        if (angle >= _thresholds.topThreshold) _state = _RepState.top;
        return false;
    }
  }

  bool _checkBottom(double angle) {
    if (angle > _thresholds.bottomThreshold) return false;
    _state = _RepState.bottom;
    return true;
  }

  void reset() {
    _state = _RepState.top;
    _lowest = double.infinity;
    _repCount = 0;
    _noRepCount = 0;
  }

  static LiftThresholds _thresholdsFor(String liftKey) => switch (liftKey) {
        // Knee angle: standing ≈ 170°, thighs parallel ≈ 90°.
        'squat' || 'lunge' => const LiftThresholds(descendStart: 160, bottomThreshold: 90, topThreshold: 160),
        // Hip angle: locked out ≈ 175°, hinged ≈ 60–70°.
        'deadlift' => const LiftThresholds(descendStart: 160, bottomThreshold: 70, topThreshold: 160),
        // Elbow angle: arms locked ≈ 170°, bar on chest / racked ≈ 80–90°.
        'bench_press' || 'overhead_press' || 'push_up' =>
          const LiftThresholds(descendStart: 160, bottomThreshold: 90, topThreshold: 155),
        // Elbow angle: arms long ≈ 165°, handle at the torso ≈ 75–90°.
        'row' => const LiftThresholds(descendStart: 155, bottomThreshold: 90, topThreshold: 155),
        // Hip angle: seated on the floor ≈ 95–100°, full extension ≈ 175°.
        'hip_thrust' => const LiftThresholds(descendStart: 160, bottomThreshold: 100, topThreshold: 170),
        _ => throw ArgumentError.value(liftKey, 'liftKey', 'not a launch lift'),
      };
}

enum _RepState { top, descending, bottom, recovering }

/// Angles in degrees that drive [RepCounter] for one lift.
class LiftThresholds {
  const LiftThresholds({required this.descendStart, required this.bottomThreshold, required this.topThreshold});

  /// Below this the lifter has left the top position.
  final double descendStart;

  /// At or below this the rep reached full depth.
  final double bottomThreshold;

  /// At or above this (after full depth) the rep is complete.
  final double topThreshold;
}
