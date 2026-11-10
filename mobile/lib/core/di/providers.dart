import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../iap/revenuecat_service.dart';
import '../../shared/services/api/supabase_client.dart';
import '../../shared/services/local_db/database.dart';
import '../../shared/services/sync/sync_queue.dart';

part 'providers.g.dart';

// ── Supabase ──────────────────────────────────────────────────────────────

@riverpod
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}

// ── Secure storage ────────────────────────────────────────────────────────

@riverpod
FlutterSecureStorage secureStorage(Ref ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}

// ── API client (Dio) ──────────────────────────────────────────────────────

@riverpod
TektoDioClient dioClient(Ref ref) => TektoDioClient();

// ── Local database (Drift) ────────────────────────────────────────────────

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

// ── Offline sync queue ────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
SyncQueue syncQueue(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioClientProvider);
  return SyncQueue(db: db, dio: dio);
}

// ── RevenueCat ────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
RevenueCatService revenueCatService(Ref ref) {
  return RevenueCatService();
}

// ── Connectivity ──────────────────────────────────────────────────────────

/// True while any network interface is up. Offline-first UI (Constitution I) branches on this.
@Riverpod(keepAlive: true)
Stream<bool> isOnline(Ref ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) => r.any((c) => c != ConnectivityResult.none);
  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online);
}

// ── App language ──────────────────────────────────────────────────────────

/// App locale chosen by the user (onboarding language step, Settings); null = device locale.
@Riverpod(keepAlive: true)
class AppLocale extends _$AppLocale {
  @override
  Locale? build() => null;

  void set(String languageCode) => state = Locale(languageCode);
}
