import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/coach/domain/coach_provider.dart';
import 'package:tekto/features/coach/ui/plan_change_pending_card.dart';
import 'package:tekto/features/coach/ui/widgets/message_rating_widget.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/shared/models/coach_model.dart';

/// Slide-up coach panel accessible from any screen via a FAB.
///
/// Displays conversation history, an input field, and a quota remaining badge
/// for free users.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key, this.screenContext});

  /// Current route + optional context (e.g. "library/barbell-squat").
  final String? screenContext;

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coachState = ref.watch(coachControllerProvider);
    final entitlement = ref.watch(entitlementProvider).valueOrNull;
    final isPro = entitlement?.isPro ?? false;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // ---- Handle ----
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.onDarkSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // ---- Title + quota badge ----
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base, vertical: 4),
            child: Row(
              children: [
                const Text('AI Coach',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (!isPro)
                  _QuotaBadge(coachState: coachState),
              ],
            ),
          ),
          const Divider(height: 1),
          // ---- Messages ----
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: coachState.messages.length,
              itemBuilder: (context, index) {
                final msg = coachState.messages[index];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          // ---- Error ----
          if (coachState.status == CoachStatus.error &&
              coachState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: Text(
                _friendlyError(coachState.errorMessage!),
                style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          // ---- Input ----
          _InputRow(
            controller: _inputController,
            loading: coachState.status == CoachStatus.loading,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    ref
        .read(coachControllerProvider.notifier)
        .sendMessage(text, screenContext: widget.screenContext);
  }

  String _friendlyError(String code) {
    if (code == 'QUOTA_EXCEEDED') {
      return 'You\'ve used your 3 free questions this week. Upgrade to Pro for unlimited coaching.';
    }
    return 'Something went wrong. Please try again.';
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _QuotaBadge extends StatelessWidget {
  const _QuotaBadge({required this.coachState});
  final CoachState coachState;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.charcoalElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Free: 3 Q/week',
          style: TextStyle(fontSize: 12, color: AppColors.onDarkSecondary),
        ),
      );
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message});
  final CoachMessageModel message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'user';

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color:
                  isUser ? AppColors.accent : AppColors.charcoalElevated,
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            ),
            child: Text(
              message.content,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          // Plan change card
          if (!isUser && message.planChangeProposed != null)
            PlanChangePendingCard(message: message),
          // Rating (assistant only)
          if (!isUser)
            MessageRatingWidget(messageId: message.id),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.loading,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Ask your coach…',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: AppSizes.minTapTarget,
                height: AppSizes.minTapTarget,
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: AppColors.accent),
                        onPressed: onSend,
                      ),
              ),
            ],
          ),
        ),
      );
}
