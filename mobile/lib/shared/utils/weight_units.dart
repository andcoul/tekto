/// kg ⇄ lb for display and input (FR-034). Storage is always kg.
library;

const _lbPerKg = 2.2046226218;

double kgToUnit(double kg, String unit) => unit == 'lb' ? kg * _lbPerKg : kg;

double unitToKg(double value, String unit) => unit == 'lb' ? value / _lbPerKg : value;

/// "16", "17.5", "35.3": one decimal at most, no trailing ".0".
String formatWeight(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble() ? rounded.toStringAsFixed(0) : rounded.toStringAsFixed(1);
}

/// Parses user input in either decimal style ("17.5" or "17,5"); null if not a number ≥ 0.
double? parseWeight(String text) {
  final v = double.tryParse(text.trim().replaceAll(',', '.'));
  if (v == null || v < 0 || v.isNaN || v.isInfinite) return null;
  return v;
}
