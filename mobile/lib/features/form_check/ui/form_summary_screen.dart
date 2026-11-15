import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/form_check/cue_engine.dart';
import '../../../shared/services/form_check/form_score_calculator.dart';
import 'beta_badge.dart';

/// Post-set form check summary (FR-024): score, reps counted, flagged reps, the cues seen
/// during the set and one prioritized tip, in the user's language.
class FormSummaryScreen extends StatelessWidget {
  const FormSummaryScreen({
    super.key,
    required this.summary,
    required this.exerciseSlug,
  });

  final FormSetSummary summary;
  final String exerciseSlug;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    const engine = CueEngine();
    final topTip = fr ? summary.topTipFr : summary.topTipEn;
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [Text(l.formCheckSummaryTitle), const SizedBox(width: 8), const BetaBadge()]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Semantics(
                label: '${l.formCheckScoreLabel}: ${summary.score} / 100',
                excludeSemantics: true,
                child: _FormScoreGauge(score: summary.score),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.repeat, color: AppColors.accent),
                const SizedBox(width: 8),
                Flexible(child: Text(l.formCheckRepsCounted(summary.repCount), style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(summary.flaggedReps.isEmpty ? Icons.check_circle_outline : Icons.flag_outlined,
                    color: summary.flaggedReps.isEmpty ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    summary.flaggedReps.isEmpty ? l.formCheckNoFlaggedReps : l.formCheckFlaggedReps(summary.flaggedReps.join(', ')),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (summary.cuesShown.isNotEmpty) ...[
              Text(l.formCheckTechniqueNotes, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              for (final key in summary.cuesShown)
                if (engine.cueFor(key) case final cue?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.onDarkSecondary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(fr ? cue.textFr : cue.textEn, style: Theme.of(context).textTheme.bodySmall)),
                      ],
                    ),
                  ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.formCheckTopTipLabel, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.accent)),
                    const SizedBox(height: 8),
                    Text(topTip.isEmpty ? l.formCheckGreatForm : topTip),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l.formCheckBetaNote, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.onDarkSecondary)),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(onPressed: () => context.pop(), child: Text(l.formCheckDone)),
            const SizedBox(height: AppSpacing.sm),
            // Re-enters through the gate, so a used free try leads to the paywall.
            OutlinedButton(
              onPressed: () => context.pushReplacement('/form-check/$exerciseSlug'),
              child: Text(l.formCheckTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Arc gauge widget
// ---------------------------------------------------------------------------

class _FormScoreGauge extends StatelessWidget {
  const _FormScoreGauge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        height: 180,
        child: CustomPaint(
          painter: _GaugePainter(score: score),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 56, color: _scoreColor(score)),
                ),
                Text(
                  '/ 100',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.onDarkSecondary),
                ),
              ],
            ),
          ),
        ),
      );

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return AppColors.accent;
    return Colors.red;
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.score});
  final int score;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.charcoalElevated
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Value arc
    final scorePaint = Paint()
      ..color = _scoreColor(score)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * (score / 100),
      false,
      scorePaint,
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return AppColors.accent;
    return Colors.red;
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.score != score;
}
