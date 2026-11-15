import 'cue_engine.dart';
import 'form_score_calculator.dart';
import 'pose_analyzer.dart';
import 'rep_counter.dart';

/// What the live screen shows after one frame.
class FrameOutcome {
  const FrameOutcome({required this.cues, required this.repCount, required this.repCompleted});

  /// At most 3, highest severity first; only "adjust lighting" when confidence is low.
  final List<FormCue> cues;
  final int repCount;
  final bool repCompleted;
}

/// Camera-free half of a form-check set: counts reps, tags each frame with its rep, adds
/// rep-level cues and times frame processing. [FormCheckService] feeds it from ML Kit.
///
/// Holds only angles and cue keys, never image data (Principle II).
class FormCheckPipeline {
  FormCheckPipeline({required this.liftKey, CueEngine cueEngine = const CueEngine()})
      : _counter = RepCounter(liftKey: liftKey),
        _angleKey = PoseAnalyzer.repAngleKey(liftKey)!,
        _cueEngine = cueEngine;

  final String liftKey;
  final RepCounter _counter;
  final String _angleKey;
  final CueEngine _cueEngine;
  final _frames = <FormFrameResult>[];
  final _processingMs = <int>[];

  /// Lifts where turning back up before full depth means "go deeper".
  static const _depthLifts = {'squat', 'lunge'};

  int get repCount => _counter.repCount;

  /// Median per-frame processing time so far; null before the first timed frame.
  double? get medianProcessingMs => _processingMs.isEmpty ? null : medianOf(_processingMs);

  /// Adds one analysed frame. [processing] is the time from camera frame to result.
  FrameOutcome add(FormFrameResult frame, {Duration? processing}) {
    if (processing != null) _processingMs.add(processing.inMilliseconds);

    final angle = frame.jointAngleSnapshot[_angleKey];
    final noRepsBefore = _counter.noRepCount;
    final completed = angle != null && _counter.update(angle);

    final cues = [...frame.activeCues];
    if (_counter.noRepCount > noRepsBefore && _depthLifts.contains(liftKey)) cues.add('depth_too_shallow');

    // The frame that finishes a rep belongs to it; frames mid-rep to the next one.
    final repIndex = completed ? _counter.repCount : (_counter.inRep ? _counter.repCount + 1 : 0);
    final tagged = frame.copyWith(activeCues: cues, repDetected: completed, repIndex: repIndex);
    _frames.add(tagged);

    return FrameOutcome(cues: _cueEngine.evaluate(tagged), repCount: _counter.repCount, repCompleted: completed);
  }

  /// Post-set summary (FR-024).
  FormSetSummary finish({required String language}) => FormScoreCalculator(cueEngine: _cueEngine).calculate(
        frames: List.unmodifiable(_frames),
        liftKey: liftKey,
        language: language,
        repCount: _counter.repCount,
      );
}

double medianOf(List<int> values) {
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd ? sorted[mid].toDouble() : (sorted[mid - 1] + sorted[mid]) / 2;
}
