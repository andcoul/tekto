import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';

import '../api/supabase_client.dart';
import '../local_db/database.dart';

const _maxRetries = 3;
const _pending = 'pending';
const _failed = 'failed';

/// Offline-first write queue (Principle I: every live-workout write goes through here).
///
/// Writes are stored locally in Drift's `sync_queue` table. On reconnect,
/// [flush] processes the queue in insertion order and replays each operation
/// against the Supabase REST API via [TektoDioClient].
class SyncQueue {
  SyncQueue({required this.db, required this.dio}) {
    _startConnectivityListener();
  }

  final AppDatabase db;
  final TektoDioClient dio;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  void _startConnectivityListener() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        flush();
      }
    });
  }

  /// Enqueue a write operation. Returns immediately — does NOT wait for network.
  Future<void> enqueue({
    required String operation, // 'insert' | 'update' | 'delete' (case-insensitive)
    required String tableName,
    required Map<String, dynamic> payload,
  }) async {
    await db.into(db.syncQueueTable).insert(
          SyncQueueTableCompanion.insert(
            operation: operation.toLowerCase(),
            tableName_: tableName,
            payload: jsonEncode(payload),
          ),
        );
  }

  /// Process all pending queue entries in insertion order.
  /// Called automatically on reconnect and manually after app foreground.
  /// A row that fails [_maxRetries] times is marked `failed` for manual review and
  /// never blocks the rows after it.
  Future<void> flush() async {
    final pending = await (db.select(db.syncQueueTable)
          ..where((q) => q.status.equals(_pending))
          ..orderBy([(q) => OrderingTerm.asc(q.id)]))
        .get();

    for (final entry in pending) {
      try {
        await _replay(entry);
        await (db.delete(db.syncQueueTable)
              ..where((q) => q.id.equals(entry.id)))
            .go();
      } on Exception {
        final retries = entry.retryCount + 1;
        await (db.update(db.syncQueueTable)
              ..where((q) => q.id.equals(entry.id)))
            .write(SyncQueueTableCompanion(
              retryCount: Value(retries),
              status: Value(retries >= _maxRetries ? _failed : _pending),
            ));
      }
    }
  }

  Future<void> _replay(SyncQueueTableData entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    final path = '/rest/v1/${entry.tableName_}';

    switch (entry.operation) {
      case 'insert':
        await dio.post(path, data: payload);
      case 'update':
        final id = payload['id'] as String?;
        if (id == null) return;
        await dio.patch('$path?id=eq.$id', data: payload);
      case 'delete':
        final id = payload['id'] as String?;
        if (id == null) return;
        await dio.delete('$path?id=eq.$id');
    }
  }

  Future<int> pendingCount() => db.syncQueueTable
      .count(where: (q) => q.status.equals(_pending))
      .getSingle();

  void dispose() {
    _connectivitySub?.cancel();
  }
}
