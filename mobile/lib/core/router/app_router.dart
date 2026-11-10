import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/data/auth_service.dart';
import '../../features/auth/ui/auth_screen.dart';
import '../../features/coach/ui/coach_screen.dart';
import '../../features/form_check/ui/form_check_screen.dart';
import '../../features/form_check/ui/form_summary_screen.dart';
import '../../features/library/ui/exercise_detail_screen.dart';
import '../../features/library/ui/exercise_list_screen.dart';
import '../../features/onboarding/ui/health_disclaimer_screen.dart';
import '../../features/onboarding/ui/onboarding_quiz_screen.dart';
import '../../features/onboarding/ui/plan_generation_screen.dart';
import '../../features/onboarding/ui/trial_offer_screen.dart';
import '../../features/plan/ui/adaptation_summary_screen.dart';
import '../../features/plan/ui/exercise_swap_sheet.dart';
import '../../features/plan/ui/plan_overview_screen.dart';
import '../../features/progress/ui/progress_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/subscription/ui/paywall_screen.dart';
import '../../features/subscription/ui/subscription_settings_screen.dart';
import '../../features/workout/ui/home_screen.dart';
import '../../features/workout/ui/live_workout_screen.dart';
import '../../features/workout/ui/workout_summary_screen.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation.startsWith('/auth') ||
          state.matchedLocation.startsWith('/onboarding');

      if (!isAuthenticated && !isAuthRoute) {
        return '/auth';
      }
      if (isAuthenticated && state.matchedLocation == '/auth') {
        return '/home';
      }
      return null;
    },
    routes: [
      // ── Auth ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // ── Onboarding ──────────────────────────────────────────────────────
      GoRoute(
        path: '/onboarding/disclaimer',
        builder: (context, state) => const HealthDisclaimerScreen(),
      ),
      GoRoute(
        path: '/onboarding/quiz',
        builder: (context, state) => const OnboardingQuizScreen(),
      ),
      GoRoute(
        path: '/onboarding/generating',
        builder: (context, state) => const PlanGenerationScreen(),
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
          return WorkoutSummaryScreen(sessionId: sessionId);
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
              return FormSummaryScreen(exerciseSlug: slug);
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
        ],
      ),

      // ── Paywall ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/paywall',
        builder: (context, state) {
          final feature = state.uri.queryParameters['feature'] ?? 'pro';
          return PaywallScreen(featureKey: feature);
        },
      ),

      // ── Plan adaptation ─────────────────────────────────────────────────
      GoRoute(
        path: '/plan/adaptation',
        builder: (context, state) => const AdaptationSummaryScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
}
