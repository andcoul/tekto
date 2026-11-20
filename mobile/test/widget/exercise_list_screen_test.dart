// T158 — library equipment filter uses the FR-001 vocabulary with localized labels (FR-013, FR-033).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/library/domain/exercise_provider.dart';
import 'package:tekto/features/library/ui/exercise_list_screen.dart';
import 'package:tekto/shared/models/exercise_model.dart';

ExerciseModel _ex(String slug, String name, List<String> equipment) => ExerciseModel(
      slug: slug, nameEn: name, nameFr: name, equipment: equipment, musclePrimary: const ['lats'], //
      muscleSecondary: const [], cuesEn: const [], cuesFr: const [], commonMistakesEn: const [],
      commonMistakesFr: const [], formCheckSupported: false,
    );

final _library = [
  _ex('pull-up', 'Pull-up', ['bodyweight', 'pull_up_bar']),
  _ex('dumbbell-row', 'Dumbbell row', ['dumbbell']),
  _ex('leg-press', 'Leg press', ['machine']),
];

Future<void> _pump(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [exercisesProvider.overrideWith((ref) async => _library)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ExerciseListScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The horizontal list holding the filter chips (the search field is also a Scrollable).
Finder _chipRow() => find.ancestor(of: find.byType(FilterChip).first, matching: find.byType(Scrollable)).first;

Future<void> _tapChip(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(FilterChip, label);
  await tester.drag(_chipRow(), const Offset(3000, 0)); // back to the first chip
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(chip, 200, scrollable: _chipRow());
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('equipment chips cover the FR-001 vocabulary with English labels', (tester) async {
    await _pump(tester, const Locale('en'));
    for (final label in [
      'Barbell', 'Dumbbells / kettlebells', 'Cable', 'Machines', 'Resistance bands', 'Pull-up bar', //
      'Dip station', 'Bench', 'Bodyweight'
    ]) {
      final chip = find.widgetWithText(FilterChip, label);
      await tester.scrollUntilVisible(chip, 200, scrollable: _chipRow());
      expect(chip, findsOneWidget, reason: label);
    }
    expect(find.widgetWithText(FilterChip, 'Pull_up_bar'), findsNothing);
  });

  testWidgets('filtering by pull-up bar or machines shows only those exercises', (tester) async {
    await _pump(tester, const Locale('en'));
    await _tapChip(tester, 'Pull-up bar');
    expect(find.text('Pull-up'), findsOneWidget);
    expect(find.text('Dumbbell row'), findsNothing);
    await _tapChip(tester, 'Pull-up bar');
    await _tapChip(tester, 'Machines');
    expect(find.text('Leg press'), findsOneWidget);
    expect(find.text('Pull-up'), findsNothing);
  });

  testWidgets('chips and the search hint are in French for French users', (tester) async {
    await _pump(tester, const Locale('fr'));
    for (final label in ['Grands dorsaux', 'Élastiques', 'Barre de traction', 'Banc']) {
      final chip = find.widgetWithText(FilterChip, label);
      await tester.scrollUntilVisible(chip, 200, scrollable: _chipRow());
      expect(chip, findsOneWidget, reason: label);
    }
    expect(find.text('Search exercises…'), findsNothing);
  });
}
