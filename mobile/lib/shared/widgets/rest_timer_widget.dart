import 'package:flutter/material.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/app_theme.dart';

/// "1:30", "0:15", "10:00".
String formatRest(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// Rest countdown panel shown under the set list while resting, so the logged sets
/// (and any PR badge) stay visible. Display only: the clock lives in the workout
/// controller. Large digits for the gym; "Skip rest" is the one primary action.
class RestTimerWidget extends StatelessWidget {
  const RestTimerWidget({
    super.key,
    required this.secondsRemaining,
    required this.onSkip,
    required this.onAdjust,
  });

  final int secondsRemaining;
  final VoidCallback onSkip;

  /// Called with −15 or +15 (FR-008: the running rest is adjustable).
  final void Function(int deltaSec) onAdjust;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.charcoalElevated,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.workoutRestTimerLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.onDarkSecondary)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _AdjustButton(label: '−15', tooltip: l.workoutRestRemove15, onTap: () => onAdjust(-15)),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                formatRest(secondsRemaining),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ),
          _AdjustButton(label: '+15', tooltip: l.workoutRestAdd15, onTap: () => onAdjust(15)),
        ]),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppSizes.minTapTarget,
          child: ElevatedButton(onPressed: onSkip, child: Text(l.workoutSkipRest)),
        ),
      ]),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.label, required this.tooltip, required this.onTap});
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 64,
          height: AppSizes.minTapTarget,
          child: OutlinedButton(onPressed: onTap, child: Text(label)),
        ),
      );
}
