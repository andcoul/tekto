import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/shared/services/form_check/form_score_calculator.dart';

/// Post-set form check summary screen.
///
/// Shows:
///   - Form score arc gauge (0–100)
///   - Rep count
///   - Cues displayed during the set
///   - Top actionable tip in user's language
///   - "Done" and "Try again" buttons
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
    return Scaffold(
      appBar: AppBar(title: const Text('Form Summary')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Score gauge ----
            Center(
              child: _FormScoreGauge(score: summary.score),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Rep count ----
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.repeat, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  '${summary.repCount} reps counted',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Cues ----
            if (summary.cuesShown.isNotEmpty) ...[
              Text(
                'Technique notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              ...summary.cuesShown.map(
                (cueKey) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: AppColors.onDarkSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cueKey.replaceAll('_', ' ').capitalizeFirst(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],

            // ---- Top tip ----
            if (summary.topTipEn.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top tip',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.accent,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(summary.topTipEn),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // ---- Actions ----
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => context.go('/form-check/$exerciseSlug'),
              child: const Text('Try again'),
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

extension _StringExt on String {
  String capitalizeFirst() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
