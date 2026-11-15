// T121 — written before plate_calculator.dart (FR-042). Weights are in the user's unit.
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/workout/domain/plate_calculator.dart';

void main() {
  test('100 kg on a 20 kg bar → 25 + 15 per side, exact', () {
    final r = plateLoad(100, unit: 'kg');
    expect(r.bar, 20);
    expect(r.perSide, [25, 15]);
    expect(r.loadable, 100);
    expect(r.exact, isTrue);
  });

  test('225 lb on a 45 lb bar → 45 + 45 per side', () {
    final r = plateLoad(225, unit: 'lb');
    expect(r.bar, 45);
    expect(r.perSide, [45, 45]);
    expect(r.exact, isTrue);
  });

  test('61 kg is not exact: nearest loadable is 60 kg (smallest plate 1.25 kg)', () {
    final r = plateLoad(61, unit: 'kg');
    expect(r.exact, isFalse);
    expect(r.loadable, 60);
    expect(r.perSide, [20]);
  });

  test('62 kg rounds up to 62.5 kg', () {
    final r = plateLoad(62, unit: 'kg');
    expect([r.loadable, r.exact], [62.5, false]);
    expect(r.perSide, [20, 1.25]);
  });

  test('uses the largest plates first', () {
    expect(plateLoad(142.5, unit: 'kg').perSide, [25, 25, 10, 1.25]);
    expect(plateLoad(185, unit: 'lb').perSide, [45, 25]);
  });

  test('a weight at or below the bar is the empty bar', () {
    for (final w in [0.0, 10.0, 20.0]) {
      final r = plateLoad(w, unit: 'kg');
      expect([r.loadable, r.perSide], [20, <double>[]]);
      expect(r.exact, w == 20);
    }
  });
}
