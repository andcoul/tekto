import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/features/coach/data/coach_conversation_repository.dart';
import 'package:tekto/features/coach/data/coach_message_repository.dart';
import 'package:tekto/features/coach/domain/coach_quota_service.dart';
import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';

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
  });

  final List<CoachMessageModel> messages;
  final CoachStatus status;
  final String? errorMessage;
  final String? conversationId;

  CoachState copyWith({
    List<CoachMessageModel>? messages,
    CoachStatus? status,
    String? errorMessage,
    String? conversationId,
  }) =>
      CoachState(
        messages: messages ?? this.messages,
        status: status ?? this.status,
        errorMessage: errorMessage,
        conversationId: conversationId ?? this.conversationId,
      );
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class CoachController extends StateNotifier<CoachState> {
  CoachController({
    required CoachConversationRepository conversationRepo,
    required CoachMessageRepository messageRepo,
    required CoachQuotaService quotaService,
    required TektoDioClient apiClient,
    required String userId,
    required bool isPro,
  })  : _conversationRepo = conversationRepo,
        _messageRepo = messageRepo,
        _quotaService = quotaService,
        _apiClient = apiClient,
        _userId = userId,
        _isPro = isPro,
        super(const CoachState(messages: []));

  final CoachConversationRepository _conversationRepo;
  final CoachMessageRepository _messageRepo;
  final CoachQuotaService _quotaService;
  final TektoDioClient _apiClient;
  final String _userId;
  final bool _isPro;

  /// Sends a message to the AI coach.
  ///
  /// [screenContext] is the current route name + optional exerciseSlug or
  /// sessionId, injected automatically by the UI layer.
  Future<void> sendMessage(String text, {String? screenContext}) async {
    // Quota check
    final canSend = await _quotaService.canSendMessage(_userId, isPro: _isPro);
    if (!canSend) {
      state = state.copyWith(
        status: CoachStatus.error,
        errorMessage: 'QUOTA_EXCEEDED',
      );
      return;
    }

    final conversation =
        await _conversationRepo.getOrCreateActiveConversation(_userId);
    final conversationId = conversation.id;

    // Optimistically add user message to local state
    final userMsg = CoachMessageModel(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      role: 'user',
      content: text,
      screenContext: screenContext,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      status: CoachStatus.loading,
      conversationId: conversationId,
      errorMessage: null,
    );

    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/functions/v1/coach-message',
        data: {
          'message': text,
          'screen_context': screenContext,
          'conversation_id': conversationId,
        },
      );

      final content = response.data?['content'] as String? ?? '';
      final planChange = response.data?['plan_change'];

      final assistantMsg = CoachMessageModel(
        id: 'remote-${DateTime.now().millisecondsSinceEpoch}',
        conversationId: conversationId,
        role: 'assistant',
        content: content,
        planChangeProposed: planChange != null
            ? Map<String, dynamic>.from(planChange as Map)
            : null,
        createdAt: DateTime.now(),
      );

      await _quotaService.incrementUsage(_userId);

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        status: CoachStatus.idle,
      );
    } catch (e) {
      state = state.copyWith(
        status: CoachStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Applies a coach-proposed plan change.
  Future<void> confirmChange(String messageId) async {
    try {
      await _apiClient.post<void>(
        '/functions/v1/coach-confirm-change',
        data: {'message_id': messageId},
      );
      // Mark locally
      state = state.copyWith(
        messages: state.messages.map((m) {
          if (m.id == messageId) {
            return m.copyWith(planChangeApplied: true);
          }
          return m;
        }).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        status: CoachStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Rejects a proposed plan change without a server call.
  void rejectChange(String messageId) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id == messageId) {
          return m.copyWith(planChangeRejected: true);
        }
        return m;
      }).toList(),
    );
  }
}

final coachControllerProvider =
    StateNotifierProvider<CoachController, CoachState>((ref) {
  throw UnimplementedError('Override in ProviderScope with userId and isPro');
});
