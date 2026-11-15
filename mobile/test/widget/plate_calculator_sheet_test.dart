// T122 — written before plate_calculator_sheet.dart (FR-042). Offline, in the user's unit.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/workout/ui/plate_calculator_sheet.dart';

Future<void> pump(WidgetTester tester, {required double weight, String unit = 'kg', Locale locale = const Locale('en')}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: PlateCalculatorSheet(initialWeight: weight, unit: unit)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the plates per side for the current weight', (tester) async {
    await pump(tester, weight: 100);
    expect(find.text('25 kg · 15 kg'), findsOneWidget);
    expect(find.textContaining('nearest'), findsNothing);
  });

  testWidgets('updates as the weight is edited and flags a weight that is not loadable', (tester) async {
    await pump(tester, weight: 100);
    await tester.enterText(find.byType(TextField), '61');
    await tester.pump();
    expect(find.text('20 kg'), findsOneWidget);
    expect(find.text("61 kg can't be loaded exactly — nearest is 60 kg"), findsOneWidget);
  });

  testWidgets('lb users get a 45 lb bar and lb plates', (tester) async {
    await pump(tester, weight: 225, unit: 'lb');
    expect(find.text('45 lb · 45 lb'), findsOneWidget);
  });

  testWidgets('at or below the bar weight: empty bar', (tester) async {
    await pump(tester, weight: 20);
    expect(find.text('Empty bar'), findsOneWidget);
  });

  testWidgets('localized', (tester) async {
    await pump(tester, weight: 100, locale: const Locale('fr'));
    expect(find.text('Par côté'), findsOneWidget);
  });
}
