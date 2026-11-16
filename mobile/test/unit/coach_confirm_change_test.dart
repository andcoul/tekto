// T074 (app side) — confirming or rejecting a coach plan change (FR-018,
// contracts/backend-api.md `POST /coach-confirm-change`).
import 'package:tekto/shared/services/sync/sync_queue.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/features/coach/domain/coach_provider.dart';
import 'package:tekto/features/plan/data/plan_repository.dart';
import 'package:tekto/features/plan/domain/plan_provider.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';

class _FakeApi extends TektoDioClient {
  _FakeApi() : super(accessToken: () => null, baseUrl: 'http://localhost', anonKey: 'test');

  final posts = <(String, Object?)>[];
  bool offline = false;

  @override
  Future<Response<T>> post<T>(String path, {Object? data, Map<String, dynamic>? queryParameters}) async {
    posts.add((path, data));
    if (offline) {
      throw DioException(requestOptions: RequestOptions(path: path), type: DioExceptionType.connectionError);
    }
    return Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200);
  }
}

class _FakePlans implements PlanRepository {
  final refreshed = <String>[];

  @override
  Future<void> refreshActivePlan(String userId) async => refreshed.add(userId);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late AppDatabase db;
  late _FakeApi api;
  late _FakePlans plans;
  late ProviderContainer c;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = _FakeApi();
    plans = _FakePlans();
    c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      dioClientProvider.overrideWithValue(api),
      // No connectivity plugin in unit tests: a queue that never sees a network change.
      syncQueueProvider.overrideWith(
        (ref) => SyncQueue(db: db, dio: api, connectivityChanges: const Stream<List<ConnectivityResult>>.empty()),
      ),
      planRepositoryProvider.overrideWithValue(plans),
      currentUserIdProvider.overrideWithValue('user-1'),
      entitlementProvider.overrideWith((ref) => Stream.value(EntitlementState.free)),
    ]);
  });

  tearDown(() async {
    c.dispose();
    await db.close();
  });

  CoachController ctrl() => c.read(coachControllerProvider.notifier);

  test('Apply sends confirmed: true and refreshes the cached plan', () async {
    await ctrl().confirmChange('m-1');
    expect(api.posts.map((p) => p.$1), ['/functions/v1/coach-confirm-change']);
    expect(api.posts.single.$2, {'message_id': 'm-1', 'confirmed': true});
    expect(plans.refreshed, ['user-1']);
    expect(c.read(coachControllerProvider).status, isNot(CoachStatus.error));
  });

  test('No thanks records the rejection on the server and dismisses the card', () async {
    await ctrl().rejectChange('m-1');
    expect(api.posts.map((p) => p.$1), ['/functions/v1/coach-confirm-change']);
    expect(api.posts.single.$2, {'message_id': 'm-1', 'confirmed': false});
    expect(c.read(coachControllerProvider).rejectedChangeIds, {'m-1'});
    expect(plans.refreshed, isEmpty, reason: 'nothing changed, so no refresh');
  });

  test('No thanks offline still dismisses the card (the change stays unapplied on the server)', () async {
    api.offline = true;
    await ctrl().rejectChange('m-1');
    expect(c.read(coachControllerProvider).rejectedChangeIds, {'m-1'});
    expect(c.read(coachControllerProvider).status, isNot(CoachStatus.error));
  });
}
