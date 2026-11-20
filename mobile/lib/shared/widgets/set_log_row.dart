import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../utils/weight_units.dart';

enum SetRowMode {
  /// Already logged: shows what was done and a PR badge when it set a record.
  done,

  /// The set to log now: inputs and the screen's one primary action ("Done").
  current,

  /// Later sets: target only, no action (Constitution VI: one primary action).
  upcoming,
}

/// RPE values offered in the picker: 1–10 in 0.5 steps (FR-007).
final kRpeValues = [for (var i = 2; i <= 20; i++) i / 2];

String _rpeLabel(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// One set of an exercise in the live workout. Tap targets ≥ 48 dp (Constitution VI).
/// Haptics use Flutter's built-in [HapticFeedback]: light on "Done", heavy on a new PR.
class SetLogRow extends StatefulWidget {
  const SetLogRow({
    super.key,
    required this.setNumber,
    required this.mode,
    required this.unit,
    required this.repsMin,
    required this.repsMax,
    this.prefillWeightKg,
    this.prefillReps,
    this.loggedWeightKg,
    this.loggedReps,
    this.loggedRpe,
    this.isPr = false,
    this.onDone,
  });

  final int setNumber;
  final SetRowMode mode;

  /// 'kg' | 'lb' — what the user sees and types; callbacks always receive kg.
  final String unit;
  final int repsMin;
  final int repsMax;
  final double? prefillWeightKg;
  final int? prefillReps;
  final double? loggedWeightKg;
  final int? loggedReps;
  final double? loggedRpe;
  final bool isPr;
  final Future<void> Function(double weightKg, int reps, double? rpe)? onDone;

  @override
  State<SetLogRow> createState() => _SetLogRowState();
}

class _SetLogRowState extends State<SetLogRow> {
  late final TextEditingController _weightCtrl;
  late int _reps;
  double? _rpe;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final kg = widget.prefillWeightKg;
    _weightCtrl = TextEditingController(text: kg == null ? '' : formatWeight(kgToUnit(kg, widget.unit)));
    _reps = widget.prefillReps ?? widget.repsMin;
  }

  @override
  void didUpdateWidget(SetLogRow old) {
    super.didUpdateWidget(old);
    // The row just turned into a logged PR (not a PR restored on resume).
    if (widget.isPr && !old.isPr && widget.mode == SetRowMode.done) {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final onDone = widget.onDone;
    if (onDone == null || _saving) return;
    final typed = _weightCtrl.text.trim().isEmpty ? 0.0 : parseWeight(_weightCtrl.text);
    if (typed == null) return; // not a number: keep the row open
    setState(() => _saving = true);
    await HapticFeedback.lightImpact();
    await onDone(unitToKg(typed, widget.unit), _reps, _rpe);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final unitLabel = widget.unit == 'lb' ? l.unitLb : l.unitKg;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: widget.mode == SetRowMode.done ? AppColors.glacier.withValues(alpha: 0.12) : AppColors.mid,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: widget.isPr ? Border.all(color: AppColors.mint, width: 1.5) : null,
      ),
      child: switch (widget.mode) {
        SetRowMode.done => _doneRow(l, theme, unitLabel),
        SetRowMode.upcoming => _upcomingRow(l, theme),
        SetRowMode.current => _currentRow(l, theme, unitLabel),
      },
    );
  }

  Widget _number(ThemeData theme, {required bool highlight}) => SizedBox(
        width: 32,
        child: Text(
          '${widget.setNumber}',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: highlight ? AppColors.glacier : AppColors.mist),
        ),
      );

  Widget _doneRow(AppLocalizations l, ThemeData theme, String unitLabel) {
    final kg = widget.loggedWeightKg ?? 0;
    return SizedBox(
      height: AppSizes.minTapTarget,
      child: Row(children: [
        _number(theme, highlight: true),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            l.workoutSetDone(formatWeight(kgToUnit(kg, widget.unit)), unitLabel, widget.loggedReps ?? 0),
            style: theme.textTheme.titleMedium,
          ),
        ),
        if (widget.loggedRpe != null)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Text('${l.workoutRpe} ${_rpeLabel(widget.loggedRpe!)}', style: theme.textTheme.bodyMedium),
          ),
        if (widget.isPr)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emoji_events, color: AppColors.mint, size: 20),
            const SizedBox(width: 4),
            Text(l.workoutNewPR, style: theme.textTheme.labelLarge?.copyWith(color: AppColors.mint)),
          ])
        else
          const Icon(Icons.check_circle, color: AppColors.glacier),
      ]),
    );
  }

  Widget _upcomingRow(AppLocalizations l, ThemeData theme) => SizedBox(
        height: AppSizes.minTapTarget,
        child: Row(children: [
          _number(theme, highlight: false),
          const SizedBox(width: AppSpacing.sm),
          Text(l.workoutTargetReps(widget.repsMin, widget.repsMax),
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.mist)),
        ]),
      );

  Widget _currentRow(AppLocalizations l, ThemeData theme, String unitLabel) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            _number(theme, highlight: true),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                key: const Key('weight-input'),
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  suffixText: unitLabel,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _CounterButton(
              icon: Icons.remove,
              tooltip: l.workoutFewerReps,
              onTap: _reps > 1 ? () => setState(() => _reps--) : null,
            ),
            SizedBox(
              width: 36,
              child: Text('$_reps', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            ),
            _CounterButton(icon: Icons.add, tooltip: l.workoutMoreReps, onTap: () => setState(() => _reps++)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Row(children: [
            SizedBox(
              height: AppSizes.minTapTarget,
              child: DropdownButton<double?>(
                key: const Key('rpe-select'),
                value: _rpe,
                hint: Text(l.workoutRpe),
                underline: const SizedBox.shrink(),
                onChanged: (v) => setState(() => _rpe = v),
                items: [
                  DropdownMenuItem<double?>(value: null, child: Text('${l.workoutRpe} –')),
                  for (final v in kRpeValues) DropdownMenuItem<double?>(value: v, child: Text(_rpeLabel(v))),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SizedBox(
                height: AppSizes.minTapTarget,
                child: ElevatedButton(onPressed: _saving ? null : _done, child: Text(l.workoutDone)),
              ),
            ),
          ]),
        ],
      );
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: AppSizes.minTapTarget,
        height: AppSizes.minTapTarget,
        child: IconButton(icon: Icon(icon, size: 20), tooltip: tooltip, onPressed: onTap, padding: EdgeInsets.zero),
      );
}
