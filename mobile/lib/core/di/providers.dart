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
SupabaseClient supabaseClient(SupabaseClientRef ref) {
  return Supabase.instance.client;
}

// ── Secure storage ────────────────────────────────────────────────────────

@riverpod
FlutterSecureStorage secureStorage(SecureStorageRef ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
}

// ── API client (Dio) ──────────────────────────────────────────────────────

@riverpod
TektoDioClient dioClient(DioClientRef ref) {
  final storage = ref.watch(secureStorageProvider);
  return TektoDioClient(storage);
}

// ── Local database (Drift) ────────────────────────────────────────────────

@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

// ── Offline sync queue ────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
SyncQueue syncQueue(SyncQueueRef ref) {
  final db = ref.watch(appDatabaseProvider);
  final dio = ref.watch(dioClientProvider);
  return SyncQueue(db: db, dio: dio);
}

// ── RevenueCat ────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
RevenueCatService revenueCatService(RevenueCatServiceRef ref) {
  return RevenueCatService();
}
