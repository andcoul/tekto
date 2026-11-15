import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/features/coach/data/coach_conversation_repository.dart';
import 'package:tekto/features/coach/data/coach_message_repository.dart';
import 'package:tekto/features/coach/domain/coach_quota_service.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
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
  });

  final List<CoachMessageModel> messages;
  final CoachStatus status;
  final String? errorMessage;
  final String? conversationId;

  /// Messages whose proposed plan change the user dismissed ("No thanks"). Local only:
  /// a dismissed change is simply never confirmed on the server.
  final Set<String> rejectedChangeIds;

  CoachState copyWith({
    List<CoachMessageModel>? messages,
    CoachStatus? status,
    String? errorMessage,
    String? conversationId,
    Set<String>? rejectedChangeIds,
  }) =>
      CoachState(
        messages: messages ?? this.messages,
        status: status ?? this.status,
        errorMessage: errorMessage,
        conversationId: conversationId ?? this.conversationId,
        rejectedChangeIds: rejectedChangeIds ?? this.rejectedChangeIds,
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
      state = state.copyWith(status: CoachStatus.error, errorMessage: 'QUOTA_EXCEEDED');
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

    try {
      final response = await ref.read(dioClientProvider).post<Map<String, dynamic>>(
        '/functions/v1/coach-message',
        data: {
          'message': text,
          'screen_context': screenContext,
          'conversation_id': conversationId,
        },
      );

      final content = response.data?['content'] as String? ?? '';
      final planChange = response.data?['plan_change'];

      final assistantMsg = await _messageRepo.addMessage(
        conversationId: conversationId,
        role: 'assistant',
        content: content,
        planChangeProposed: planChange is Map ? Map<String, dynamic>.from(planChange) : null,
      );

      await _quotaService.incrementUsage(userId);

      state = state.copyWith(messages: [...state.messages, assistantMsg], status: CoachStatus.idle);
    } catch (e) {
      state = state.copyWith(status: CoachStatus.error, errorMessage: e.toString());
    }
  }

  /// Applies a coach-proposed plan change.
  Future<void> confirmChange(String messageId) async {
    try {
      await ref.read(dioClientProvider).post<void>(
        '/functions/v1/coach-confirm-change',
        data: {'message_id': messageId},
      );
      await _messageRepo.markPlanChangeApplied(messageId);
      state = state.copyWith(
        messages: [
          for (final m in state.messages) m.id == messageId ? m.copyWith(planChangeApplied: true) : m,
        ],
      );
    } catch (e) {
      state = state.copyWith(status: CoachStatus.error, errorMessage: e.toString());
    }
  }

  /// Dismisses a proposed plan change without a server call.
  void rejectChange(String messageId) {
    state = state.copyWith(rejectedChangeIds: {...state.rejectedChangeIds, messageId});
  }
}

final coachControllerProvider = NotifierProvider<CoachController, CoachState>(CoachController.new);
