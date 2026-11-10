import 'package:tekto/shared/services/form_check/cue_engine.dart';
import 'package:tekto/shared/services/form_check/pose_analyzer.dart';

// ---------------------------------------------------------------------------
// Output types
// ---------------------------------------------------------------------------

class FormSetSummary {
  const FormSetSummary({
    required this.score,
    required this.cuesShown,
    required this.topTipEn,
    required this.topTipFr,
    required this.repCount,
  });

  /// Form quality score 0–100.
  final int score;

  /// All distinct cue keys that were shown during this set.
  final List<String> cuesShown;

  /// The single most actionable tip in English.
  final String topTipEn;

  /// The single most actionable tip in French.
  final String topTipFr;

  final int repCount;
}

// ---------------------------------------------------------------------------
// FormScoreCalculator
// ---------------------------------------------------------------------------

/// Aggregates per-frame violation data into a post-set [FormSetSummary].
///
/// score = (1 - violationRate) × 100, rounded to int (0–100).
/// topTip is the most frequently occurring cue key across all frames.
///
/// Principle V: unit tested.
class FormScoreCalculator {
  const FormScoreCalculator({required CueEngine cueEngine})
      : _cueEngine = cueEngine;

  final CueEngine _cueEngine;

  /// Calculates a [FormSetSummary] from a list of [FormFrameResult]s.
  ///
  /// [repCount] is passed in from [RepCounter] since it owns the rep state.
  FormSetSummary calculate({
    required List<FormFrameResult> frames,
    required String liftKey,
    required String language,
    required int repCount,
  }) {
    if (frames.isEmpty) {
      return const FormSetSummary(
        score: 100,
        cuesShown: [],
        topTipEn: '',
        topTipFr: '',
        repCount: 0,
      );
    }

    // Count violations per frame (frames with ≥1 violation = violating frame)
    int violatingFrames = 0;
    final cueFrequency = <String, int>{};

    for (final frame in frames) {
      final cues = _cueEngine.evaluate(frame);
      // Filter out the confidence-gate warning from violation count
      final realCues = cues.where((c) => c.key != 'adjust_lighting').toList();

      if (realCues.isNotEmpty) violatingFrames++;

      for (final cue in realCues) {
        cueFrequency[cue.key] = (cueFrequency[cue.key] ?? 0) + 1;
      }
    }

    final violationRate = violatingFrames / frames.length;
    final score = ((1 - violationRate) * 100).round().clamp(0, 100);

    // Most frequent cue key
    String topCueKey = '';
    int maxFreq = 0;
    cueFrequency.forEach((key, freq) {
      if (freq > maxFreq) {
        maxFreq = freq;
        topCueKey = key;
      }
    });

    final topCue = _cueEngine.evaluate(
      FormFrameResult(
        activeCues: topCueKey.isNotEmpty ? [topCueKey] : [],
        repDetected: false,
        jointAngleSnapshot: {},
        confidence: 1.0,
      ),
    );

    final topTipEn =
        topCue.isNotEmpty ? topCue.first.textEn : 'Great form! Keep it up.';
    final topTipFr =
        topCue.isNotEmpty ? topCue.first.textFr : 'Excellent! Continuez comme ça.';

    return FormSetSummary(
      score: score,
      cuesShown: cueFrequency.keys.toList(),
      topTipEn: topTipEn,
      topTipFr: topTipFr,
      repCount: repCount,
    );
  }
}
