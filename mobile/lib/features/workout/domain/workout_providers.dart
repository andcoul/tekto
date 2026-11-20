import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../shared/services/health/health_sync_service.dart';
import '../../plan/domain/plan_provider.dart';
import '../data/set_log_repository.dart';
import '../data/workout_log_repository.dart';
import '../data/workout_session_repository.dart';
import 'live_session.dart';

final workoutSessionRepositoryProvider =
    Provider<WorkoutSessionRepository>((ref) => WorkoutSessionRepository(ref.watch(appDatabaseProvider)));

final setLogRepositoryProvider = Provider<SetLogRepository>((ref) => SetLogRepository(
      db: ref.watch(appDatabaseProvider),
      syncQueue: ref.watch(syncQueueProvider),
      clock: ref.watch(clockProvider),
    ));

/// Null when signed out.
final workoutLogRepositoryProvider = Provider<WorkoutLogRepository?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return WorkoutLogRepository(
    db: ref.watch(appDatabaseProvider),
    syncQueue: ref.watch(syncQueueProvider),
    userId: userId,
    clock: ref.watch(clockProvider),
  );
});

final healthPlatformProvider = Provider<HealthPlatform>((ref) => PluginHealthPlatform());

final healthSyncServiceProvider = Provider<HealthSyncService>((ref) => HealthSyncService(
      platform: ref.watch(healthPlatformProvider),
      db: ref.watch(appDatabaseProvider),
      syncQueue: ref.watch(syncQueueProvider),
    ));

/// Unit and health-sync preference of the signed-in user, from the device cache.
final userPrefsProvider = FutureProvider.autoDispose<UserPrefs>(
    (ref) => ref.watch(workoutSessionRepositoryProvider).userPrefs(ref.watch(currentUserIdProvider)));

/// Today's session of the active plan (FR-006).
final todayStatusProvider = FutureProvider.autoDispose<TodayStatus>((ref) async {
  final plan = await ref.watch(activePlanProvider.future);
  if (plan == null) return const NoActivePlan();
  return ref.watch(workoutSessionRepositoryProvider).today(
        planId: plan.id,
        currentWeek: plan.currentWeek,
        weekday: ref.watch(clockProvider)().weekday,
      );
});

final liveSessionProvider = FutureProvider.autoDispose.family<LiveSession, String>(
    (ref, sessionId) => ref.watch(workoutSessionRepositoryProvider).loadSession(sessionId));

final workoutSummaryProvider = FutureProvider.autoDispose.family<WorkoutSummary, String>(
    (ref, workoutLogId) => ref.watch(workoutSessionRepositoryProvider).summarize(workoutLogId));
