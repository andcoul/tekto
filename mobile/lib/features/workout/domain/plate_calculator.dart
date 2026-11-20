/// Plate calculator for barbell exercises (FR-042, T122). Pure; works offline.
library;

/// Plates to load on each side of the bar for a target weight.
class PlateLoad {
  const PlateLoad({required this.bar, required this.perSide, required this.loadable, required this.exact});

  /// Bar weight in the user's unit.
  final double bar;

  /// Plates for one side, heaviest first.
  final List<double> perSide;

  /// Total weight actually loaded (bar + both sides).
  final double loadable;

  /// False when the target cannot be loaded exactly; [loadable] is then the nearest weight.
  final bool exact;
}

const _bar = {'kg': 20.0, 'lb': 45.0};
const _plates = {
  'kg': [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25],
  'lb': [45.0, 35.0, 25.0, 10.0, 5.0, 2.5],
};

/// Plates per side for [weight] in [unit] ('kg' | 'lb'). Rounds to the nearest loadable weight
/// (ties round down); a target at or below the bar gives the empty bar.
PlateLoad plateLoad(double weight, {required String unit}) {
  final bar = _bar[unit] ?? _bar['kg']!;
  final plates = _plates[unit] ?? _plates['kg']!;
  if (weight <= bar) return PlateLoad(bar: bar, perSide: const [], loadable: bar, exact: weight == bar);

  // Every multiple of the smallest plate is loadable per side with these plate sets.
  final step = plates.last;
  final perSideTarget = (weight - bar) / 2;
  final steps = perSideTarget / step;
  final rounded = (steps - steps.floor() > 0.5 ? steps.ceil() : steps.floor()) * step;

  final perSide = <double>[];
  var remaining = rounded;
  for (final p in plates) {
    while (remaining >= p - 1e-9) {
      perSide.add(p);
      remaining -= p;
    }
  }
  final loadable = bar + 2 * rounded;
  return PlateLoad(bar: bar, perSide: perSide, loadable: loadable, exact: (loadable - weight).abs() < 1e-9);
}
