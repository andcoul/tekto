import 'package:flutter/material.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/weight_units.dart';
import '../domain/plate_calculator.dart';

/// Bottom sheet showing the plates per side for a barbell weight (FR-042, T122). Works offline;
/// weights are in the user's unit. Starts from the current set's weight and can be edited.
class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({super.key, required this.initialWeight, required this.unit});

  final double initialWeight;

  /// 'kg' | 'lb'.
  final String unit;

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late final TextEditingController _controller = TextEditingController(text: formatWeight(widget.initialWeight));
  late double _weight = widget.initialWeight;

  /// Plate sizes need two decimals (1.25 kg); weights use the shared one-decimal format.
  static String _format(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final load = plateLoad(_weight, unit: widget.unit);
    final unit = widget.unit;
    final plates = load.perSide.isEmpty ? l.platesEmptyBar : load.perSide.map((p) => '${_format(p)} $unit').join(' · ');

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.platesTitle, style: text.titleLarge),
          const SizedBox(height: AppSpacing.base),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.platesWeightLabel, suffixText: unit),
            onChanged: (v) => setState(() => _weight = parseWeight(v) ?? 0),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l.platesPerSide, style: text.labelLarge?.copyWith(color: AppColors.onDarkSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(plates, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(l.platesBar('${_format(load.bar)} $unit'), style: text.bodyMedium),
          if (!load.exact && _weight > load.bar)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l.platesNotExact('${_format(_weight)} $unit', '${_format(load.loadable)} $unit'),
                style: text.bodyMedium?.copyWith(color: AppColors.accent),
              ),
            ),
        ],
      ),
    );
  }
}
