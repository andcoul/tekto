/// State machine for counting reps for a given lift key.
///
/// States: NEUTRAL → DESCENDING → BOTTOM → ASCENDING → (rep counted → NEUTRAL)
///
/// A rep is counted when the state machine transitions from ASCENDING back to
/// NEUTRAL (i.e. returns to the starting position after a full cycle).
/// A partial reversal before reaching BOTTOM is detected as a no-rep.
///
/// Principle V: this class is unit tested.
class RepCounter {
  RepCounter({required this.liftKey}) {
    _thresholds = _thresholdsFor(liftKey);
  }

  final String liftKey;
  late final _LiftThresholds _thresholds;

  _RepState _state = _RepState.neutral;
  int _repCount = 0;
  int _noRepCount = 0;
  bool _reachedBottom = false;

  int get repCount => _repCount;
  int get noRepCount => _noRepCount;

  /// Feed a [jointAngle] measurement (from [PoseAnalyzer]) to advance the
  /// state machine.
  ///
  /// Returns `true` when a completed rep has just been counted.
  bool update(double jointAngle) {
    switch (_state) {
      case _RepState.neutral:
        if (_isDescending(jointAngle)) {
          _state = _RepState.descending;
          _reachedBottom = false;
        }
        return false;

      case _RepState.descending:
        if (_atBottom(jointAngle)) {
          _state = _RepState.bottom;
          _reachedBottom = true;
        } else if (_isAscending(jointAngle) && !_reachedBottom) {
          // Reversed before bottom → no-rep
          _noRepCount++;
          _state = _RepState.neutral;
        }
        return false;

      case _RepState.bottom:
        if (_isAscending(jointAngle)) {
          _state = _RepState.ascending;
        }
        return false;

      case _RepState.ascending:
        if (_atTop(jointAngle)) {
          _repCount++;
          _state = _RepState.neutral;
          _reachedBottom = false;
          return true; // rep completed
        }
        if (_isDescending(jointAngle)) {
          // Reversed during ascent — not a no-rep, back to descending
          _state = _RepState.descending;
        }
        return false;
    }
  }

  void reset() {
    _state = _RepState.neutral;
    _repCount = 0;
    _noRepCount = 0;
    _reachedBottom = false;
  }

  // ---------------------------------------------------------------------------
  // Transition predicates
  // ---------------------------------------------------------------------------

  bool _isDescending(double angle) => angle < _thresholds.descendStart;
  bool _atBottom(double angle) => angle <= _thresholds.bottomThreshold;
  bool _isAscending(double angle) => angle > _thresholds.ascendStart;
  bool _atTop(double angle) => angle >= _thresholds.topThreshold;

  // ---------------------------------------------------------------------------
  // Per-lift thresholds
  // ---------------------------------------------------------------------------

  static _LiftThresholds _thresholdsFor(String liftKey) {
    switch (liftKey) {
      case 'squat':
      case 'lunge':
        return const _LiftThresholds(
          descendStart: 160, // knee angle starts bending
          bottomThreshold: 90, // parallel or below
          ascendStart: 95,
          topThreshold: 160,
        );
      case 'deadlift':
      case 'romanian_deadlift':
        return const _LiftThresholds(
          descendStart: 160,
          bottomThreshold: 70,
          ascendStart: 80,
          topThreshold: 160,
        );
      case 'bench_press':
      case 'overhead_press':
        return const _LiftThresholds(
          descendStart: 160,
          bottomThreshold: 90,
          ascendStart: 95,
          topThreshold: 155,
        );
      case 'hip_thrust':
        return const _LiftThresholds(
          descendStart: 160,
          bottomThreshold: 100,
          ascendStart: 110,
          topThreshold: 170,
        );
      case 'row':
        return const _LiftThresholds(
          descendStart: 160,
          bottomThreshold: 90,
          ascendStart: 100,
          topThreshold: 155,
        );
      case 'push_up':
        return const _LiftThresholds(
          descendStart: 160,
          bottomThreshold: 90,
          ascendStart: 95,
          topThreshold: 155,
        );
      default:
        return const _LiftThresholds(
          descendStart: 160,
          bottomThreshold: 90,
          ascendStart: 95,
          topThreshold: 160,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Supporting types
// ---------------------------------------------------------------------------

enum _RepState { neutral, descending, bottom, ascending }

class _LiftThresholds {
  const _LiftThresholds({
    required this.descendStart,
    required this.bottomThreshold,
    required this.ascendStart,
    required this.topThreshold,
  });

  final double descendStart;
  final double bottomThreshold;
  final double ascendStart;
  final double topThreshold;
}
