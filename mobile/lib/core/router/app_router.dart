import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/auth/data/user_profile_provider.dart';
import '../../features/auth/ui/auth_screen.dart';
import '../../features/coach/ui/coach_screen.dart';
import '../../features/form_check/ui/form_check_screen.dart';
import '../../features/form_check/ui/form_summary_screen.dart';
import '../../features/library/ui/exercise_detail_screen.dart';
import '../../features/library/ui/exercise_list_screen.dart';
import '../../features/onboarding/domain/onboarding_controller.dart';
import '../../features/onboarding/domain/onboarding_gate.dart';
import '../../features/onboarding/ui/consent_screen.dart';
import '../../features/onboarding/ui/health_disclaimer_screen.dart';
import '../../features/onboarding/ui/onboarding_quiz_screen.dart';
import '../../features/onboarding/ui/plan_generation_screen.dart';
import '../../features/onboarding/ui/trial_offer_screen.dart';
import '../../features/onboarding/ui/welcome_screen.dart';
import '../../features/plan/domain/adaptation_provider.dart';
import '../../features/plan/ui/adaptation_summary_screen.dart';
import '../../features/plan/ui/plan_overview_screen.dart';
import '../../features/progress/ui/progress_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/subscription/ui/paywall_screen.dart';
import '../../features/subscription/ui/subscription_settings_screen.dart';
import '../../features/workout/ui/home_screen.dart';
import '../../features/workout/ui/live_workout_screen.dart';
import '../../features/workout/ui/workout_summary_screen.dart';
import '../../shared/services/form_check/form_score_calculator.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Re-run redirects when auth or the profile changes, without rebuilding the router
  // (rebuilding would reset navigation on every state change).
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authStateProvider, (_, __) => refresh.value++)
    ..listen(userProfileProvider, (_, __) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: false,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthenticated = ref.read(authStateProvider).value != null;
      final profile = ref.read(userProfileProvider);
      final onboarding = ref.read(onboardingControllerProvider);

      // 1. Signed out: only the welcome screen and sign-in (the profile is saved per user).
      if (!isAuthenticated) return signedOutRedirect(location);

      final inOnboarding = location.startsWith('/onboarding');
      if (profile.hasValue) {
        final row = profile.value;
        // 2. New user (no profile yet) → onboarding.
        if (row == null && !inOnboarding) return '/onboarding/disclaimer';
        // 3. Accepted an older consent text → consent again (T044).
        if (row != null && needsReconsent(row['consent_version'] as String?) && location != '/onboarding/reconsent') {
          return '/onboarding/reconsent';
        }
      }
      if (location == '/auth' || location == '/onboarding/welcome') return '/home';

      // 4. Disclaimer → consent → quiz order (Constitution II/III).
      return onboardingRedirect(
        location: location,
        disclaimerAccepted: onboarding.disclaimerAccepted,
        consentGiven: onboarding.consentGiven,
        planGenerated: onboarding.result != null,
      );
    },
    routes: [
      // ── Auth ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // ── Onboarding ──────────────────────────────────────────────────────
      GoRoute(
        path: '/onboarding/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/onboarding/disclaimer',
        builder: (context, state) => const HealthDisclaimerScreen(),
      ),
      GoRoute(
        path: '/onboarding/consent',
        builder: (context, state) => const ConsentScreen(),
      ),
      GoRoute(
        path: '/onboarding/reconsent',
        builder: (context, state) => const ConsentScreen(reconsent: true),
      ),
      GoRoute(
        path: '/onboarding/quiz',
        builder: (context, state) => const OnboardingQuizScreen(),
      ),
      GoRoute(
        path: '/onboarding/generating',
        // `?upgrade=1`: a trial was just started → regenerate as an AI plan (FR-004).
        builder: (context, state) => PlanGenerationScreen(upgrade: state.uri.queryParameters['upgrade'] == '1'),
      ),
      GoRoute(
        path: '/onboarding/trial',
        builder: (context, state) => const TrialOfferScreen(),
      ),

      // ── Main shell ──────────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/plan',
        builder: (context, state) => const PlanOverviewScreen(),
      ),

      // ── Workout ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/workout/:sessionId',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return LiveWorkoutScreen(sessionId: sessionId);
        },
      ),
      GoRoute(
        path: '/workout/:sessionId/summary',
        builder: (context, state) {
          final sessionId = state.pathParameters['sessionId']!;
          return WorkoutSummaryScreen(sessionId: sessionId, workoutLogId: state.uri.queryParameters['log']);
        },
      ),

      // ── Library ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/library',
        builder: (context, state) => const ExerciseListScreen(),
        routes: [
          GoRoute(
            path: ':exerciseSlug',
            builder: (context, state) {
              final slug = state.pathParameters['exerciseSlug']!;
              return ExerciseDetailScreen(exerciseSlug: slug);
            },
          ),
        ],
      ),

      // ── Coach ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/coach',
        builder: (context, state) => const CoachScreen(),
      ),

      // ── Form Check ──────────────────────────────────────────────────────
      GoRoute(
        path: '/form-check/:exerciseSlug',
        builder: (context, state) {
          final slug = state.pathParameters['exerciseSlug']!;
          return FormCheckScreen(exerciseSlug: slug);
        },
        routes: [
          GoRoute(
            path: 'summary',
            builder: (context, state) {
              final slug = state.pathParameters['exerciseSlug']!;
              // The form-check screen pushes the computed summary as `extra`.
              return FormSummaryScreen(
                exerciseSlug: slug,
                summary: state.extra! as FormSetSummary,
              );
            },
          ),
        ],
      ),

      // ── Progress ────────────────────────────────────────────────────────
      GoRoute(
        path: '/progress',
        builder: (context, state) => const ProgressScreen(),
      ),

      // ── Settings ────────────────────────────────────────────────────────
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'subscription',
            builder: (context, state) => const SubscriptionSettingsScreen(),
          ),
          // Edit onboarding answers (FR-046, T131): the quiz without its language step.
          GoRoute(
            path: 'profile',
            builder: (context, state) => const OnboardingQuizScreen(editProfile: true),
          ),
        ],
      ),

      // ── Paywall ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/paywall',
        // Feature-specific clip and copy: /paywall?feature=form_check|coach|adaptive_plan|general.
        builder: (context, state) => PaywallScreen(feature: PaywallFeature.fromKey(state.uri.queryParameters['feature'])),
      ),

      // ── Plan adaptation ─────────────────────────────────────────────────
      GoRoute(
        path: '/plan/adaptation',
        builder: (context, state) =>
            AdaptationSummaryScreen(summary: state.extra! as AdaptationSummary),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(AppLocalizations.of(context).commonNotFound)),
    ),
  );
}
