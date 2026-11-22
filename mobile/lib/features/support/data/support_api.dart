// Support chat (FR-054; contracts/backend-api.md §10). Messages stream from `support_messages`
// (Realtime); sending goes through `support-message`, which answers with the AI assistant.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';

class SupportMessage {
  const SupportMessage({required this.id, required this.sender, required this.body, required this.createdAt});
  factory SupportMessage.fromRow(Map<String, dynamic> r) => SupportMessage(
        id: r['id'] as String,
        sender: r['sender'] as String,
        body: r['body'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
      );
  final String id;

  /// user | ai | agent
  final String sender;
  final String body;
  final DateTime createdAt;
}

class SupportSendResult {
  const SupportSendResult({required this.waitingForAgent, required this.messages});
  final bool waitingForAgent;
  final List<SupportMessage> messages;
}

abstract class SupportApi {
  /// Messages of the user's open thread, oldest first, updating live.
  Stream<List<SupportMessage>> watch();
  Future<SupportSendResult> send(String body, {bool wantHuman = false});
}

class SupabaseSupportApi implements SupportApi {
  SupabaseSupportApi(this._ref);
  final Ref _ref;
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Stream<List<SupportMessage>> watch() async* {
    final thread = await _db
        .from('support_threads')
        .select('id')
        .eq('user_id', _db.auth.currentUser!.id)
        .neq('status', 'closed')
        .maybeSingle();
    if (thread == null) {
      yield const [];
      return;
    }
    yield* _db
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', thread['id'] as String)
        .order('created_at')
        .map((rows) => [for (final r in rows) SupportMessage.fromRow(r)]);
  }

  @override
  Future<SupportSendResult> send(String body, {bool wantHuman = false}) async {
    final res = await _ref
        .read(dioClientProvider)
        .post<Map<String, dynamic>>('/functions/v1/support-message', data: {'body': body, 'want_human': wantHuman});
    final data = res.data ?? const {};
    return SupportSendResult(
      waitingForAgent: data['status'] == 'waiting_agent',
      messages: [for (final m in (data['messages'] as List? ?? const [])) SupportMessage.fromRow((m as Map).cast())],
    );
  }
}

final supportApiProvider = Provider<SupportApi>((ref) => SupabaseSupportApi(ref));
