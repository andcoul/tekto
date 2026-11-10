import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_service.dart';
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

/// The signed-in user's `users` row (null before onboarding saves it). Drives onboarding
/// entry and re-consent in the router.
@riverpod
Future<Map<String, dynamic>?> userProfile(Ref ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return Supabase.instance.client.from('users').select('consent_version').eq('id', user.id).maybeSingle();
}

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

      // 1. Everything except /auth needs a signed-in user (the profile is saved per user).
      if (!isAuthenticated) return location == '/auth' ? null : '/auth';

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
      if (location == '/auth') return '/home';

      // 4. Disclaimer → consent → quiz order (Constitution II/III).
      return onboardingRedirect(
        location: location,
        disclaimerAccepted: onboarding.disclaimerAccepted,
        consentGiven: onboarding.consentGiven,
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
        ],
      ),

      // ── Paywall ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/paywall',
        builder: (context, state) {
          // Feature-specific copy is chosen by the caller via ProGateWidget (T055/T056).
          return const PaywallScreen();
        },
      ),

      // ── Plan adaptation ─────────────────────────────────────────────────
      GoRoute(
        path: '/plan/adaptation',
        builder: (context, state) =>
            AdaptationSummaryScreen(summary: state.extra! as AdaptationSummary),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
}
