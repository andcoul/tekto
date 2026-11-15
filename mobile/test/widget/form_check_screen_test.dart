// T066/T067 — form-check gate (paywall surface, Constitution V), Beta label, summary screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/form_check/data/form_check_repository.dart';
import 'package:tekto/features/form_check/domain/form_check_free_try_service.dart';
import 'package:tekto/features/form_check/domain/form_check_gate.dart';
import 'package:tekto/features/form_check/ui/beta_badge.dart';
import 'package:tekto/features/form_check/ui/form_check_screen.dart';
import 'package:tekto/features/form_check/ui/form_summary_screen.dart';
import 'package:tekto/features/library/domain/exercise_provider.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/features/subscription/domain/pro_offers.dart';
import 'package:tekto/features/subscription/ui/paywall_screen.dart';
import 'package:tekto/features/workout/domain/workout_controller.dart';
import 'package:tekto/shared/models/exercise_model.dart';
import 'package:tekto/shared/services/form_check/form_score_calculator.dart';

class _Workout extends WorkoutController {
  _Workout(this.active);
  final bool active;
  @override
  WorkoutState build() => WorkoutState(isWorkoutActive: active);
}

class _FreeTry implements FormCheckFreeTryService {
  _FreeTry({required this.used});
  final bool used;
  final checked = <String>[];

  @override
  Future<FormCheckAccess> check({required String userId, required String liftKey, required bool isPro}) async {
    checked.add(liftKey);
    if (isPro) return FormCheckAccess.pro;
    return used ? FormCheckAccess.blocked : FormCheckAccess.freeTry;
  }
}

ExerciseModel _exercise(String slug, {String? liftKey}) => ExerciseModel(
      slug: slug, nameEn: slug, nameFr: slug, equipment: const ['barbell'], musclePrimary: const ['quadriceps'],
      muscleSecondary: const [], cuesEn: const [], cuesFr: const [], commonMistakesEn: const [], commonMistakesFr: const [],
      formCheckSupported: liftKey != null, formCheckLiftKey: liftKey,
    );

final _library = [_exercise('barbell-back-squat', liftKey: 'squat'), _exercise('cable-fly')];

List<Override> _overrides({required bool pro, required bool usedTry, bool workoutActive = false, _FreeTry? freeTry}) => [
      currentUserIdProvider.overrideWithValue('u1'),
      exercisesProvider.overrideWith((ref) async => _library),
      entitlementProvider.overrideWith(
          (ref) => Stream.value(pro ? const EntitlementState(isPro: true, isTrial: false) : EntitlementState.free)),
      formCheckFreeTryServiceProvider.overrideWithValue(freeTry ?? _FreeTry(used: usedTry)),
      // The camera must not open before "Start" is pressed.
      formCheckCamerasProvider.overrideWith((ref) async => throw StateError('camera opened')),
      workoutControllerProvider.overrideWith(() => _Workout(workoutActive)),
      proOffersProvider.overrideWith((ref) async => const [ProOffer(isAnnual: true, priceString: '79,99 €', price: 79.99)]),
      isOnlineProvider.overrideWith((ref) => Stream.value(true)),
      proPurchaseProvider.overrideWithValue((_) async {}),
      proRestoreProvider.overrideWithValue(() async {}),
    ];

Widget _app(Widget home, List<Override> overrides, {Locale locale = const Locale('en')}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  group('FormCheckScreen gate', () {
    testWidgets('free user, first try on the lift: placement guide, Beta label, free-try note', (tester) async {
      final freeTry = _FreeTry(used: false);
      await tester.pumpWidget(_app(const FormCheckScreen(exerciseSlug: 'barbell-back-squat'), _overrides(pro: false, usedTry: false, freeTry: freeTry)));
      await tester.pumpAndSettle();

      expect(freeTry.checked, ['squat']); // gated on the lift key, not the slug
      expect(find.byType(BetaBadge), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Position your phone'), findsOneWidget);
      expect(find.text('Free try: one form check per lift.'), findsOneWidget);
      expect(find.text('The camera image stays on your phone and is never saved or sent.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Start form check'), findsOneWidget);
    });

    testWidgets('Pro: placement guide without the free-try note', (tester) async {
      await tester.pumpWidget(_app(const FormCheckScreen(exerciseSlug: 'barbell-back-squat'), _overrides(pro: true, usedTry: true)));
      await tester.pumpAndSettle();

      expect(find.text('Position your phone'), findsOneWidget);
      expect(find.text('Free try: one form check per lift.'), findsNothing);
    });

    testWidgets('free user who used the try: no camera, paywall on tap (sheet during a workout)', (tester) async {
      await tester.pumpWidget(_app(const FormCheckScreen(exerciseSlug: 'barbell-back-squat'),
          _overrides(pro: false, usedTry: true, workoutActive: true)));
      await tester.pumpAndSettle();

      expect(find.text("You've used your free form check for this lift."), findsOneWidget);
      expect(find.text('Start form check'), findsNothing);

      await tester.tap(find.text('Unlock unlimited form checks'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(PaywallView), findsOneWidget);
    });

    testWidgets('exercise without form check shows a message', (tester) async {
      await tester.pumpWidget(_app(const FormCheckScreen(exerciseSlug: 'cable-fly'), _overrides(pro: true, usedTry: false)));
      await tester.pumpAndSettle();
      expect(find.text("Form check isn't available for this exercise."), findsOneWidget);
    });

    testWidgets('French labels', (tester) async {
      await tester.pumpWidget(_app(const FormCheckScreen(exerciseSlug: 'barbell-back-squat'), _overrides(pro: false, usedTry: false),
          locale: const Locale('fr')));
      await tester.pumpAndSettle();
      expect(find.text('Bêta'), findsOneWidget);
      expect(find.text("Démarrer l'analyse"), findsOneWidget);
    });
  });

  group('openFormCheck from the live workout', () {
    testWidgets('used try during a workout: paywall sheet over the workout, no navigation', (tester) async {
      await tester.pumpWidget(_app(
        Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Column(children: [
              const Text('WORKOUT SCREEN'),
              TextButton(onPressed: () => openFormCheck(context, ref, 'barbell-back-squat'), child: const Text('Form check')),
            ]),
          ),
        ),
        _overrides(pro: false, usedTry: true, workoutActive: true),
      ));
      await tester.tap(find.text('Form check'));
      await tester.pumpAndSettle();

      expect(find.byType(PaywallView), findsOneWidget);
      expect(find.text('WORKOUT SCREEN'), findsOneWidget);
      expect(find.byType(FormCheckScreen), findsNothing);
    });
  });

  group('FormSummaryScreen', () {
    const summary = FormSetSummary(
      score: 64,
      cuesShown: ['knee_cave'],
      topTipEn: 'Push your knees out — keep them tracking over your toes.',
      topTipFr: "Poussez vos genoux vers l'extérieur — alignez-les avec vos orteils.",
      repCount: 5,
      flaggedReps: [2, 4],
    );

    testWidgets('lists flagged reps, reps counted, the tip and the Beta label', (tester) async {
      await tester.pumpWidget(_app(const FormSummaryScreen(summary: summary, exerciseSlug: 'barbell-back-squat'), const []));
      await tester.pumpAndSettle();

      expect(find.text('Reps to review: 2, 4'), findsOneWidget);
      expect(find.text('5 reps counted'), findsOneWidget);
      expect(find.text('64'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      // Cue in the technique notes and as the top tip.
      expect(find.text('Push your knees out — keep them tracking over your toes.'), findsNWidgets(2));
    });

    testWidgets('clean set says no reps flagged; French tip in French', (tester) async {
      const clean = FormSetSummary(score: 100, cuesShown: [], topTipEn: '', topTipFr: '', repCount: 3);
      await tester.pumpWidget(_app(const FormSummaryScreen(summary: clean, exerciseSlug: 'x'), const []));
      await tester.pumpAndSettle();
      expect(find.text('No reps flagged'), findsOneWidget);
      expect(find.text('Great form! Keep it up.'), findsOneWidget);

      await tester.pumpWidget(_app(const FormSummaryScreen(summary: summary, exerciseSlug: 'x'), const [], locale: const Locale('fr')));
      await tester.pumpAndSettle();
      expect(find.text('Répétitions à revoir : 2, 4'), findsOneWidget);
      expect(find.text("Poussez vos genoux vers l'extérieur — alignez-les avec vos orteils."), findsNWidgets(2));
    });
  });
}
