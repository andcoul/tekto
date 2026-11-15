import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../shared/services/api/supabase_client.dart';
import '../../../shared/services/local_db/daos/subscription_dao.dart';
import '../../../shared/services/local_db/database.dart';

/// The user's subscription row. Source of truth: Supabase `subscriptions` (written by the
/// RevenueCat webhook); the device cache serves offline reads (Constitution I).
class SubscriptionRepository {
  SubscriptionRepository({required SubscriptionDao subscriptionDao, required TektoDioClient api})
      : _dao = subscriptionDao,
        _api = api;

  final SubscriptionDao _dao;
  final TektoDioClient _api;

  /// The cached row; emits again whenever it changes.
  Stream<Subscription?> watchRow(String userId) => _dao.watchForUser(userId);

  /// Copies the server row to the device cache. Offline or on error the cache is kept.
  Future<void> refreshFromServer(String userId) async {
    try {
      final response = await _api.get<List<dynamic>>('/rest/v1/subscriptions',
          queryParameters: {'select': '*', 'user_id': 'eq.$userId', 'limit': '1'});
      final rows = (response.data ?? const []).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return;
      final r = rows.single;
      DateTime? date(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();
      await _dao.upsert(SubscriptionsCompanion.insert(
        id: r['id'] as String,
        userId: r['user_id'] as String,
        tier: Value(r['tier'] as String? ?? 'free'),
        isTrial: Value(r['is_trial'] as bool? ?? false),
        trialEndsAt: Value(date(r['trial_ends_at'])),
        currentPeriodEndsAt: Value(date(r['current_period_ends_at'])),
        cancelledAt: Value(date(r['cancelled_at'])),
        revenuecatCustomerId: Value(r['revenuecat_customer_id'] as String?),
        createdAt: Value(date(r['created_at']) ?? DateTime.now()),
        updatedAt: Value(date(r['updated_at']) ?? DateTime.now()),
      ));
    } on Object {
      // Offline: keep the cached row.
    }
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) => SubscriptionRepository(
      subscriptionDao: SubscriptionDao(ref.watch(appDatabaseProvider)),
      api: ref.watch(dioClientProvider),
    ));
