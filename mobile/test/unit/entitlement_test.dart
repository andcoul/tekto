// T054 — written before the entitlement rewrite (data-model subscriptions; Constitution V).
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/features/subscription/data/subscription_repository.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/daos/subscription_dao.dart';
import 'package:tekto/shared/services/local_db/database.dart';

final now = DateTime.utc(2026, 11, 15, 12);

Subscription row({String tier = 'pro', bool trial = false, DateTime? trialEnds, DateTime? periodEnds}) => Subscription(
      id: 'sub1', userId: 'u1', tier: tier, isTrial: trial, trialEndsAt: trialEnds, currentPeriodEndsAt: periodEnds,
      createdAt: now, updatedAt: now,
    );

class _FakeServer implements TektoDioClient {
  _FakeServer(this.rows, {this.offline = false});
  final List<Map<String, dynamic>> rows;
  final bool offline;

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    if (offline) throw DioException(requestOptions: RequestOptions(path: path), type: DioExceptionType.connectionError);
    return Response<T>(requestOptions: RequestOptions(path: path), data: rows as T, statusCode: 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('resolveEntitlement: isPro = tier pro AND (period active OR active trial)', () {
    test('active period → Pro', () {
      final e = resolveEntitlement(server: row(periodEnds: now.add(const Duration(days: 3))), now: now);
      expect([e.isPro, e.isTrial], [true, false]);
      expect(e.periodEndsAt, now.add(const Duration(days: 3)));
    });

    test('active trial → Pro, flagged as trial, ends at the trial end', () {
      final ends = now.add(const Duration(days: 5));
      final e = resolveEntitlement(server: row(trial: true, trialEnds: ends, periodEnds: ends), now: now);
      expect([e.isPro, e.isTrial, e.periodEndsAt], [true, true, ends]);
    });

    test('an expired trial is free', () {
      final e = resolveEntitlement(server: row(trial: true, trialEnds: now.subtract(const Duration(minutes: 1))), now: now);
      expect([e.isPro, e.isTrial], [false, false]);
    });

    test('expired period or free tier → free', () {
      expect(resolveEntitlement(server: row(periodEnds: now.subtract(const Duration(days: 1))), now: now).isPro, isFalse);
      expect(resolveEntitlement(server: row(tier: 'free', periodEnds: now.add(const Duration(days: 9))), now: now).isPro, isFalse);
    });
  });

  group('the server row wins over the RevenueCat cache on mismatch', () {
    test('server free, RevenueCat Pro → free', () {
      expect(resolveEntitlement(server: row(tier: 'free'), revenueCatIsPro: true, now: now).isPro, isFalse);
    });
    test('server Pro, RevenueCat not Pro → Pro', () {
      expect(resolveEntitlement(server: row(periodEnds: now.add(const Duration(days: 1))), revenueCatIsPro: false, now: now).isPro, isTrue);
    });
    test('no server row yet (webhook pending): RevenueCat decides; unknown → free', () {
      expect(resolveEntitlement(server: null, revenueCatIsPro: true, now: now).isPro, isTrue);
      expect(resolveEntitlement(server: null, now: now).isPro, isFalse);
    });
  });

  group('SubscriptionRepository.refreshFromServer', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('caches the server row on the device', () async {
      final repo = SubscriptionRepository(
        subscriptionDao: SubscriptionDao(db),
        api: _FakeServer([
          {'id': 'sub1', 'user_id': 'u1', 'tier': 'pro', 'is_trial': true, 'trial_ends_at': '2026-11-20T00:00:00Z',
            'current_period_ends_at': '2026-11-20T00:00:00Z', 'cancelled_at': null, 'revenuecat_customer_id': 'rc1',
            'created_at': '2026-11-13T00:00:00Z', 'updated_at': '2026-11-13T00:00:00Z'},
        ]),
      );
      await repo.refreshFromServer('u1');
      final cached = await SubscriptionDao(db).getForUser('u1');
      expect([cached!.tier, cached.isTrial], ['pro', true]);
      expect(cached.trialEndsAt!.toUtc(), DateTime.utc(2026, 11, 20));
    });

    test('offline keeps the cached row', () async {
      await SubscriptionDao(db).upsert(SubscriptionsCompanion.insert(id: 'sub1', userId: 'u1', tier: const Value('pro')));
      final repo = SubscriptionRepository(subscriptionDao: SubscriptionDao(db), api: _FakeServer(const [], offline: true));
      await repo.refreshFromServer('u1');
      expect((await SubscriptionDao(db).getForUser('u1'))!.tier, 'pro');
    });
  });
}
