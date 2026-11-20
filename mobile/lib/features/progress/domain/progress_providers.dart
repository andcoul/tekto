import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../subscription/domain/entitlement_provider.dart';
import '../data/progress_repository.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) => ProgressRepository(
      db: ref.watch(appDatabaseProvider),
      syncQueue: ref.watch(syncQueueProvider),
      clock: ref.watch(clockProvider),
    ));

/// Progress for the signed-in user from the device DB (FR-039–FR-041). Free users get the last
/// 4 weeks; Pro users the full history and muscle balance (FR-040).
final progressDataProvider = FutureProvider.autoDispose<ProgressData?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  final isPro = (await ref.watch(entitlementProvider.future)).isPro;
  return ref.watch(progressRepositoryProvider).load(userId, isPro: isPro);
});
