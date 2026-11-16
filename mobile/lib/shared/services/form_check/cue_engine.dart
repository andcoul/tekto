import 'package:tekto/shared/services/form_check/pose_analyzer.dart';

// ---------------------------------------------------------------------------
// Output types
// ---------------------------------------------------------------------------

class FormCue {
  const FormCue({
    required this.key,
    required this.textEn,
    required this.textFr,
    required this.severity,
  });

  final String key; // e.g. 'knee_cave'
  final String textEn;
  final String textFr;
  final CueSeverity severity;
}

enum CueSeverity { warning, error }

// ---------------------------------------------------------------------------
// CueEngine
// ---------------------------------------------------------------------------

/// Maps [PoseAnalyzer] angle violations to [FormCue] objects.
///
/// Confidence gate: when pose.confidence < 0.6 all cues are suppressed and
/// an "adjust_lighting" warning is emitted instead (Principle II).
///
/// At most 3 cues are returned per frame, highest severity first (FR-023).
///
/// Principle V: unit tested.
class CueEngine {
  const CueEngine();

  static const _confidenceThreshold = 0.6;
  static const _maxCuesPerFrame = 3;

  static const _cueLibrary = <String, FormCue>{
    'knee_cave': FormCue(
      key: 'knee_cave',
      textEn: 'Push your knees out — keep them tracking over your toes.',
      textFr: 'Poussez vos genoux vers l\'extérieur — alignez-les avec vos orteils.',
      severity: CueSeverity.error,
    ),
    'depth_too_shallow': FormCue(
      key: 'depth_too_shallow',
      textEn: 'Squat deeper — aim for thighs parallel to the floor.',
      textFr: 'Descendez plus bas — visez les cuisses parallèles au sol.',
      severity: CueSeverity.warning,
    ),
    'back_rounding': FormCue(
      key: 'back_rounding',
      textEn: 'Keep your back straight — engage your lats and maintain a neutral spine.',
      textFr: 'Gardez le dos droit — engagez vos dorsaux et maintenez une colonne neutre.',
      severity: CueSeverity.error,
    ),
    'elbow_flare': FormCue(
      key: 'elbow_flare',
      textEn: 'Tuck your elbows slightly — aim for 45–60° from your torso.',
      textFr: 'Rentrez légèrement les coudes — visez 45–60° par rapport au torse.',
      severity: CueSeverity.warning,
    ),
    'incomplete_lockout': FormCue(
      key: 'incomplete_lockout',
      textEn: 'Lock out at the top — fully extend your arms overhead.',
      textFr: 'Verrouillez en haut — étendez complètement les bras au-dessus.',
      severity: CueSeverity.warning,
    ),
    'incomplete_hip_extension': FormCue(
      key: 'incomplete_hip_extension',
      textEn: 'Drive your hips all the way up — squeeze your glutes at the top.',
      textFr: 'Montez les hanches jusqu\'au bout — serrez les fessiers en haut.',
      severity: CueSeverity.warning,
    ),
    'hips_sagging': FormCue(
      key: 'hips_sagging',
      textEn: 'Squeeze your glutes — keep your body in a straight plank line.',
      textFr: 'Serrez les fessiers — maintenez le corps en ligne droite.',
      severity: CueSeverity.error,
    ),
    'adjust_lighting': FormCue(
      key: 'adjust_lighting',
      textEn: 'Move to better lighting or adjust camera angle for accurate tracking.',
      textFr: 'Déplacez-vous vers un meilleur éclairage ou ajustez la caméra.',
      severity: CueSeverity.warning,
    ),
  };

  /// The cue for [key] (texts and severity), or null for an unknown key.
  FormCue? cueFor(String key) => _cueLibrary[key];

  /// Converts a [FormFrameResult] into a list of [FormCue]s.
  ///
  /// Returns `[adjustLightingCue]` when confidence is below threshold.
  List<FormCue> evaluate(FormFrameResult result) {
    if (result.confidence < _confidenceThreshold) {
      return [_cueLibrary['adjust_lighting']!];
    }

    final cues = result.activeCues.map((key) => _cueLibrary[key]).whereType<FormCue>().toList();
    // Errors before warnings; same severity keeps detection order (explicit, since
    // List.sort is not guaranteed stable).
    final order = {for (var i = 0; i < cues.length; i++) cues[i]: i};
    cues.sort((a, b) {
      final bySeverity = b.severity.index.compareTo(a.severity.index);
      return bySeverity != 0 ? bySeverity : order[a]!.compareTo(order[b]!);
    });

    return cues.take(_maxCuesPerFrame).toList();
  }
}
