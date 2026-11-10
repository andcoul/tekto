import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Set logging row — weight input, rep counter, optional RPE, and Done button.
/// Minimum tap target: 48×48 dp (Principle VI).
class SetLogRow extends StatefulWidget {
  const SetLogRow({
    super.key,
    required this.setNumber,
    this.suggestedWeightKg,
    required this.suggestedRepsMin,
    required this.suggestedRepsMax,
    required this.onLogged,
    this.isPr = false,
  });

  final int setNumber;
  final double? suggestedWeightKg;
  final int suggestedRepsMin;
  final int suggestedRepsMax;
  final void Function(double weight, int reps, double? rpe) onLogged;
  final bool isPr;

  @override
  State<SetLogRow> createState() => _SetLogRowState();
}

class _SetLogRowState extends State<SetLogRow> {
  late final TextEditingController _weightCtrl;
  late int _reps;
  double? _rpe;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(
      text: widget.suggestedWeightKg?.toStringAsFixed(1) ?? '',
    );
    _reps = widget.suggestedRepsMin;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _markDone() async {
    final weight = double.tryParse(_weightCtrl.text) ?? 0;
    if (weight <= 0) return;

    setState(() => _done = true);
    await HapticFeedback.lightImpact();

    widget.onLogged(weight, _reps, _rpe);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: _done
            ? AppColors.accent.withOpacity(0.12)
            : AppColors.charcoalSurface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        border: widget.isPr
            ? Border.all(color: AppColors.pr, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Set number
          SizedBox(
            width: 32,
            child: Text(
              '${widget.setNumber}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _done ? AppColors.accent : AppColors.onDarkSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          // Weight input
          Expanded(
            child: TextField(
              controller: _weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              enabled: !_done,
              decoration: const InputDecoration(
                hintText: 'kg',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Rep counter
          Row(
            children: [
              _CounterButton(
                icon: Icons.remove,
                onTap: _done ? null : () => setState(() {
                  if (_reps > 1) _reps--;
                }),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_reps',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _CounterButton(
                icon: Icons.add,
                onTap: _done ? null : () => setState(() => _reps++),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Done / PR button
          if (!_done)
            SizedBox(
              height: AppSizes.minTapTarget,
              child: ElevatedButton(
                onPressed: _markDone,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Done'),
              ),
            )
          else
            widget.isPr
                ? const Row(
                    children: [
                      Icon(Icons.emoji_events, color: AppColors.pr, size: 20),
                      SizedBox(width: 4),
                      Text('PR!', style: TextStyle(color: AppColors.pr)),
                    ],
                  )
                : const Icon(Icons.check_circle, color: AppColors.accent),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: AppSizes.minTapTarget,
        height: AppSizes.minTapTarget,
        child: IconButton(
          icon: Icon(icon, size: 18),
          onPressed: onTap,
          padding: EdgeInsets.zero,
        ),
      );
}
