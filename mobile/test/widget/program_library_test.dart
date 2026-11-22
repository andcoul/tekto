// FR-047 (2026-11-21): the Pro plan library — catalog parsing, filters, Pro gate and starting a program.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/plan/data/program_repository.dart';
import 'package:tekto/features/plan/domain/plan_provider.dart';
import 'package:tekto/features/plan/ui/program_library_screen.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';

/// The real catalog: every content/templates/*.json with a `catalog` block.
List<Program> _catalog() => [
      for (final f in Directory('../content/templates').listSync().whereType<File>())
        if (f.path.endsWith('.json') && !f.path.contains('package'))
          if (Program.fromBody(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>) case final p?) p,
    ]..sort((a, b) => a.order.compareTo(b.order));

class _FakeApi implements ProgramApi {
  _FakeApi(this.programs, {this.failWith});
  final List<Program> programs;
  final Object? failWith;
  final started = <String>[];
  @override
  Future<List<Program>> fetchPrograms() async => programs;
  @override
  Future<void> startProgram(String slug) async {
    if (failWith != null) throw failWith!;
    started.add(slug);
  }
}

const _pro = EntitlementState(isPro: true, isTrial: false);

Future<GoRouter> _pump(WidgetTester tester, _FakeApi api,
    {EntitlementState ent = _pro, String start = '/plan/programs'}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: start, routes: [
    GoRoute(path: '/plan', builder: (_, __) => const Scaffold(body: Text('PLAN'))),
    GoRoute(path: '/paywall', builder: (_, __) => const Scaffold(body: Text('PAYWALL'))),
    GoRoute(
      path: '/plan/programs',
      builder: (_, __) => const ProgramLibraryScreen(),
      routes: [GoRoute(path: ':slug', builder: (_, s) => ProgramDetailScreen(slug: s.pathParameters['slug']!))],
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      programApiProvider.overrideWithValue(api),
      entitlementProvider.overrideWith((ref) => Stream.value(ent)),
      activePlanProvider.overrideWith((ref) => Stream.value(null)),
      userEquipmentProvider.overrideWith((ref) async => ['dumbbell', 'bench', 'bodyweight']),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('the catalog has nine programs, including a bro split, with days in weekday order', () {
    final c = _catalog();
    expect(c.length, 9);
    final bro = c.firstWhere((p) => p.slug == 'bro-split-5x');
    expect(bro.nameEn, 'Bro split');
    expect(bro.daysPerWeek, 5);
    expect(bro.days.map((d) => d.dayOfWeek), [1, 2, 3, 4, 5]);
    expect(Program.fromBody({'slug': 'x', 'sessions': []}), isNull,
        reason: 'starter templates without catalog are hidden');
  });

  test('filters and missing equipment', () {
    final c = _catalog();
    expect(c.where((p) => programMatches(p, ProgramFilter.fivePlus)).map((p) => p.slug),
        containsAll(['bro-split-5x', 'push-pull-legs-6x', 'pairs-split-6x']));
    expect(c.where((p) => programMatches(p, ProgramFilter.home)).map((p) => p.slug), ['home-dumbbell-3x']);
    expect(c.firstWhere((p) => p.slug == 'strength-5x5-3x').missingEquipment(['dumbbell']), ['barbell', 'bench']);
    expect(c.firstWhere((p) => p.slug == 'home-dumbbell-3x').missingEquipment(['dumbbell', 'bench']), isEmpty);
  });

  testWidgets('the library lists the programs and a filter narrows them', (tester) async {
    await _pump(tester, _FakeApi(_catalog()));
    expect(find.text('Pick a classic'), findsOneWidget);
    expect(find.text('Bro split'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '3 days'));
    await tester.pumpAndSettle();
    expect(find.text('Bro split'), findsNothing);
    expect(find.text('Strength 5 × 5'), findsOneWidget);
  });

  testWidgets('a Pro user starts a program after confirming, then lands on the plan', (tester) async {
    final api = _FakeApi(_catalog());
    await _pump(tester, api, start: '/plan/programs/bro-split-5x');
    expect(find.text('Chest'), findsOneWidget);
    expect(find.textContaining("You don't have"), findsOneWidget, reason: 'dumbbell-only user sees what gets swapped');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('program-start')), 300);
    await tester.tap(find.byKey(const ValueKey('program-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Start this plan'));
    await tester.pumpAndSettle();
    expect(api.started, ['bro-split-5x']);
    expect(find.text('PLAN'), findsOneWidget);
  });

  testWidgets('a free user is sent to the paywall instead of starting', (tester) async {
    final api = _FakeApi(_catalog());
    await _pump(tester, api, ent: EntitlementState.free, start: '/plan/programs/bro-split-5x');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('program-start')), 300);
    expect(find.text('Unlock with Pro'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('program-start')));
    await tester.pumpAndSettle();
    expect(find.text('PAYWALL'), findsOneWidget);
    expect(api.started, isEmpty);
  });

  testWidgets('a program that cannot be fitted keeps the current plan and says why', (tester) async {
    await _pump(tester, _FakeApi(_catalog(), failWith: const ProgramNotSuitable(['x'])),
        start: '/plan/programs/strength-5x5-3x');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('program-start')), 300);
    await tester.tap(find.byKey(const ValueKey('program-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Start this plan'));
    await tester.pumpAndSettle();
    expect(find.textContaining("can't be fitted"), findsOneWidget);
    expect(find.text('PLAN'), findsNothing);
  });
}
