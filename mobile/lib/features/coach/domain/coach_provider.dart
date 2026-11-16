import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/features/coach/data/coach_conversation_repository.dart';
import 'package:tekto/features/coach/data/coach_message_repository.dart';
import 'package:tekto/features/coach/domain/coach_quota_service.dart';
import 'package:tekto/features/plan/domain/plan_provider.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/shared/services/api/supabase_client.dart' show ApiStatusException;
import 'package:tekto/shared/models/coach_model.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum CoachStatus { idle, loading, error }

class CoachState {
  const CoachState({
    required this.messages,
    this.status = CoachStatus.idle,
    this.errorMessage,
    this.conversationId,
    this.rejectedChangeIds = const {},
    this.quotaRemaining,
  });

  final List<CoachMessageModel> messages;
  final CoachStatus status;
  final String? errorMessage;
  final String? conversationId;

  /// Messages whose proposed plan change the user dismissed ("No thanks"). Local only:
  /// a dismissed change is simply never confirmed on the server.
  final Set<String> rejectedChangeIds;

  /// Free questions left this ISO week, from the last reply; null for Pro or before a reply.
  final int? quotaRemaining;

  CoachState copyWith({
    List<CoachMessageModel>? messages,
    CoachStatus? status,
    String? errorMessage,
    String? conversationId,
    Set<String>? rejectedChangeIds,
    int? quotaRemaining,
  }) =>
      CoachState(
        messages: messages ?? this.messages,
        status: status ?? this.status,
        errorMessage: errorMessage,
        conversationId: conversationId ?? this.conversationId,
        rejectedChangeIds: rejectedChangeIds ?? this.rejectedChangeIds,
        quotaRemaining: quotaRemaining ?? this.quotaRemaining,
      );
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class CoachController extends Notifier<CoachState> {
  @override
  CoachState build() => const CoachState(messages: []);

  CoachConversationRepository get _conversationRepo => ref.read(coachConversationRepositoryProvider);
  CoachMessageRepository get _messageRepo => ref.read(coachMessageRepositoryProvider);
  CoachQuotaService get _quotaService => ref.read(coachQuotaServiceProvider);

  bool get _isPro => ref.read(entitlementProvider).value?.isPro ?? false;

  /// Loads the free questions left this ISO week from the local count (shown on open).
  Future<void> refreshQuota() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _isPro) return;
    final remaining = await _quotaService.questionsRemaining(userId, isPro: false);
    if (remaining != null) state = state.copyWith(status: state.status, errorMessage: state.errorMessage, quotaRemaining: remaining);
  }

  /// Sends a message to the AI coach.
  ///
  /// [screenContext] is the current route name + optional exerciseSlug or
  /// sessionId, injected automatically by the UI layer.
  Future<void> sendMessage(String text, {String? screenContext}) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      state = state.copyWith(status: CoachStatus.error, errorMessage: 'NOT_SIGNED_IN');
      return;
    }

    final canSend = await _quotaService.canSendMessage(userId, isPro: _isPro);
    if (!canSend) {
      state = state.copyWith(status: CoachStatus.error, errorMessage: 'QUOTA_EXCEEDED', quotaRemaining: 0);
      return;
    }

    final conversation = await _conversationRepo.getOrCreateActiveConversation(userId);
    final conversationId = conversation.id;

    final userMsg = await _messageRepo.addMessage(
      conversationId: conversationId,
      role: 'user',
      content: text,
      screenContext: screenContext,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      status: CoachStatus.loading,
      conversationId: conversationId,
    );

    // The reply is shown while it streams; it is stored only once the server confirms it.
    final draft = CoachMessageModel(
      id: streamingMessageId,
      conversationId: conversationId,
      role: 'assistant',
      content: '',
      planChangeApplied: false,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, draft]);

    try {
      // contracts/backend-api.md `POST /coach-message` (server-sent events).
      final events = await ref.read(dioClientProvider).postEventStream(
        '/functions/v1/coach-message',
        data: {
          'conversation_id': conversationId,
          'message': text,
          if (screenContext != null) 'context': {'screen': screenContext},
        },
      );

      final buffer = StringBuffer();
      var finished = false;
      await for (final event in events) {
        switch (event.event) {
          case 'text':
            buffer.write(event.data['text'] as String? ?? '');
            _replaceDraft(draft.copyWith(content: buffer.toString()));
          case 'done':
            finished = true;
            final planChange = event.data['plan_change_proposed'];
            final quotaRemaining = (event.data['quota_remaining'] as num?)?.toInt();
            final saved = await _messageRepo.addMessage(
              id: event.data['message_id'] as String?,
              conversationId: conversationId,
              role: 'assistant',
              content: buffer.toString(),
              planChangeProposed: planChange is Map ? Map<String, dynamic>.from(planChange) : null,
            );
            await _quotaService.recordReply(userId, statusCode: 200, quotaRemaining: quotaRemaining);
            state = state.copyWith(
              messages: [for (final m in state.messages) m.id == streamingMessageId ? saved : m],
              status: CoachStatus.idle,
              quotaRemaining: quotaRemaining,
            );
          case 'error':
            finished = true;
            _failStream(event.data['error'] as String? ?? 'AI_UNAVAILABLE');
        }
      }
      // The connection closed before the server finished: same as an unavailable coach.
      if (!finished) _failStream('AI_UNAVAILABLE');
    } on ApiStatusException catch (e) {
      await _quotaService.recordReply(userId, statusCode: e.statusCode);
      final code = e.code ?? _codeForStatus(e.statusCode);
      if (code == 'QUOTA_EXCEEDED') {
        // Not answered: drop the question (the screen keeps it in the input to re-send later).
        await _messageRepo.removeMessage(userMsg.id);
        state = state.copyWith(
          messages: [for (final m in state.messages) if (m.id != userMsg.id) m],
          quotaRemaining: 0,
        );
      }
      _failStream(code);
    } on DioException {
      _failStream('NETWORK_ERROR');
    } catch (e) {
      _failStream(e.toString());
    }
  }

  /// Id of the assistant bubble while its text is streaming in.
  static const streamingMessageId = 'streaming';

  void _replaceDraft(CoachMessageModel draft) {
    state = state.copyWith(messages: [for (final m in state.messages) m.id == streamingMessageId ? draft : m]);
  }

  /// Drops the partial reply (never shown as an answer) and reports [code].
  void _failStream(String code) {
    state = state.copyWith(
      messages: [for (final m in state.messages) if (m.id != streamingMessageId) m],
      status: CoachStatus.error,
      errorMessage: code,
    );
  }

  static String _codeForStatus(int status) => switch (status) {
        429 => 'QUOTA_EXCEEDED',
        503 => 'AI_UNAVAILABLE',
        _ => 'NETWORK_ERROR',
      };

  /// Applies a coach-proposed plan change once the user taps "Apply change" (FR-018), then
  /// refreshes the cached plan so the workout and plan screens show the change.
  Future<void> confirmChange(String messageId) async {
    try {
      await ref.read(dioClientProvider).post<void>(
        '/functions/v1/coach-confirm-change',
        data: {'message_id': messageId, 'confirmed': true},
      );
      await _messageRepo.markPlanChangeApplied(messageId);
      state = state.copyWith(
        messages: [
          for (final m in state.messages) m.id == messageId ? m.copyWith(planChangeApplied: true) : m,
        ],
      );
    } catch (e) {
      state = state.copyWith(status: CoachStatus.error, errorMessage: e.toString());
      return;
    }
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      try {
        await ref.read(planRepositoryProvider).refreshActivePlan(userId);
      } on Object {
        // Applied on the server; the cache catches up on the next refresh.
      }
    }
  }

  /// Dismisses a proposed plan change. The card goes away at once; the rejection is recorded on
  /// the server (contract: `confirmed: false`) when online, and simply stays unapplied otherwise.
  Future<void> rejectChange(String messageId) async {
    state = state.copyWith(rejectedChangeIds: {...state.rejectedChangeIds, messageId});
    try {
      await ref.read(dioClientProvider).post<void>(
        '/functions/v1/coach-confirm-change',
        data: {'message_id': messageId, 'confirmed': false},
      );
    } on Object {
      // Offline or already handled: nothing was applied, so there is nothing to undo.
    }
  }
}

final coachControllerProvider = NotifierProvider<CoachController, CoachState>(CoachController.new);
