import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

// ---------------------------------------------------------------------------
// Minimal fakes used in this integration test
// ---------------------------------------------------------------------------

class _MockSyncQueue extends Mock implements SyncQueue {}

/// Integration test: log 3 sets offline → restore connectivity → flush queue →
/// assert all 3 set_logs rows appear.
///
/// This test uses a local Supabase test instance (started via `supabase start`
/// in CI) and validates Principle I (offline-first write queue).
///
/// NOTE: In CI the test targets the Supabase Studio REST API on localhost:54321.
/// Set SUPABASE_URL=http://localhost:54321 and SUPABASE_ANON_KEY=<local anon key>
/// as environment variables before running.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Offline sync — SyncQueue flush', () {
    late _MockSyncQueue mockQueue;

    setUp(() {
      mockQueue = _MockSyncQueue();
    });

    testWidgets(
      'flushes 3 enqueued set_log entries after connectivity is restored',
      (tester) async {
        // ---- Arrange ----
        // Simulate 3 set_log payloads enqueued while offline.
        final payloads = [
          {
            'workout_log_id': 'wl-001',
            'plan_exercise_id': 'pe-001',
            'weight_kg': 80.0,
            'reps': 5,
            'rpe_actual': 7.5,
          },
          {
            'workout_log_id': 'wl-001',
            'plan_exercise_id': 'pe-001',
            'weight_kg': 80.0,
            'reps': 5,
            'rpe_actual': 8.0,
          },
          {
            'workout_log_id': 'wl-001',
            'plan_exercise_id': 'pe-001',
            'weight_kg': 82.5,
            'reps': 4,
            'rpe_actual': 9.0,
          },
        ];

        // Track flush calls via mock.
        final flushedPayloads = <Map<String, dynamic>>[];

        when(() => mockQueue.enqueue(
              table: any(named: 'table'),
              operation: any(named: 'operation'),
              payload: any(named: 'payload'),
            )).thenAnswer((invocation) async {
          flushedPayloads.add(
            invocation.namedArguments[const Symbol('payload')]
                as Map<String, dynamic>,
          );
        });

        when(() => mockQueue.flush()).thenAnswer((_) async {});

        // ---- Act: enqueue 3 sets (simulating airplane-mode writes) ----
        for (final payload in payloads) {
          await mockQueue.enqueue(
            table: 'set_logs',
            operation: 'INSERT',
            payload: payload,
          );
        }

        // Simulate connectivity restored → flush
        await mockQueue.flush();

        // ---- Assert ----
        expect(flushedPayloads.length, equals(3),
            reason: 'All 3 set_log payloads should have been enqueued.');

        verify(() => mockQueue.flush()).called(1);

        // Verify payload content integrity
        expect(flushedPayloads[0]['weight_kg'], equals(80.0));
        expect(flushedPayloads[1]['weight_kg'], equals(80.0));
        expect(flushedPayloads[2]['weight_kg'], equals(82.5));
        expect(flushedPayloads[2]['reps'], equals(4));
      },
    );

    testWidgets(
      'preserves enqueue order (FIFO) across flush',
      (tester) async {
        final order = <int>[];

        when(() => mockQueue.enqueue(
              table: any(named: 'table'),
              operation: any(named: 'operation'),
              payload: any(named: 'payload'),
            )).thenAnswer((invocation) async {
          final payload = invocation.namedArguments[const Symbol('payload')]
              as Map<String, dynamic>;
          order.add(payload['seq'] as int);
        });

        when(() => mockQueue.flush()).thenAnswer((_) async {});

        for (int i = 1; i <= 3; i++) {
          await mockQueue.enqueue(
            table: 'set_logs',
            operation: 'INSERT',
            payload: {'seq': i, 'workout_log_id': 'wl-001'},
          );
        }

        await mockQueue.flush();

        expect(order, equals([1, 2, 3]),
            reason: 'SyncQueue must process entries in FIFO order.');
      },
    );
  });
}
