import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/coach/domain/coach_provider.dart';
import 'package:tekto/features/coach/ui/plan_change_pending_card.dart';
import 'package:tekto/features/coach/ui/widgets/message_rating_widget.dart';
import 'package:tekto/features/subscription/domain/entitlement_provider.dart';
import 'package:tekto/features/subscription/ui/paywall_screen.dart';
import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/widgets/pro_gate_widget.dart';

/// Slide-up coach panel accessible from any screen (FR-016, T077).
///
/// - The reply appears as it streams in.
/// - `AI_UNAVAILABLE` (or any failed reply) shows an inline message, never a spinner.
/// - `QUOTA_EXCEEDED` opens the coach paywall through [showProPaywall] (a bottom sheet during
///   a workout) and keeps the typed question in the input to re-send after upgrading.
/// - Free users see how many questions they have left this ISO week.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key, this.screenContext, this.onShowPaywall});

  /// Current route + optional context (e.g. "library/barbell-squat").
  final String? screenContext;

  /// Opens the full-screen paywall; defaults to `/paywall?feature=coach` (see [showProPaywall]).
  final void Function(PaywallFeature feature)? onShowPaywall;

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _inputController = TextEditingController();
  String _lastQuestion = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(coachControllerProvider.notifier).refreshQuota());
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final coachState = ref.watch(coachControllerProvider);
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;

    ref.listen(coachControllerProvider, (previous, next) {
      final quotaHit = next.status == CoachStatus.error && next.errorMessage == 'QUOTA_EXCEEDED';
      final wasQuotaHit = previous?.status == CoachStatus.error && previous?.errorMessage == 'QUOTA_EXCEEDED';
      if (quotaHit && !wasQuotaHit) _onQuotaExceeded();
    });

    final unavailable = coachState.status == CoachStatus.error && coachState.errorMessage != 'QUOTA_EXCEEDED';

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
          // ---- Title + remaining questions ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 4),
            child: Row(
              children: [
                Text(l.coachTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (!isPro && coachState.quotaRemaining != null) _QuotaBadge(remaining: coachState.quotaRemaining!),
              ],
            ),
          ),
          const Divider(height: 1),
          // ---- Messages (+ inline "unavailable" notice) ----
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.sm),
              itemCount: coachState.messages.length + (unavailable ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == coachState.messages.length) return _InlineNotice(text: l.coachUnavailable);
                return _MessageBubble(message: coachState.messages[index]);
              },
            ),
          ),
          // ---- Input ----
          _InputRow(
            controller: _inputController,
            hint: l.coachInputHint,
            sending: coachState.status == CoachStatus.loading,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _lastQuestion = text;
    _inputController.clear();
    ref.read(coachControllerProvider.notifier).sendMessage(text, screenContext: widget.screenContext);
  }

  void _onQuotaExceeded() {
    if (_inputController.text.isEmpty) _inputController.text = _lastQuestion;
    showProPaywall(context, ref, PaywallFeature.coach, onShowPaywall: widget.onShowPaywall);
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _QuotaBadge extends StatelessWidget {
  const _QuotaBadge({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.charcoalElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        remaining > 0 ? l.coachQuotaRemaining(remaining) : l.coachQuotaExhausted,
        style: const TextStyle(fontSize: 12, color: AppColors.onDarkSecondary),
      ),
    );
  }
}

/// A coach-side message that is not an answer (e.g. the coach is unavailable).
class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 60, bottom: AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.charcoalElevated,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            border: Border.all(color: AppColors.onDarkSecondary.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.onDarkSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
            ],
          ),
        ),
      );
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message});
  final CoachMessageModel message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'user';
    final streaming = message.id == CoachController.streamingMessageId;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 0,
        right: isUser ? 0 : 60,
        bottom: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isUser ? AppColors.accent : AppColors.charcoalElevated,
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            ),
            // While the first words are on their way, a plain ellipsis — never a spinner.
            child: Text(message.content.isEmpty && streaming ? '…' : message.content, style: const TextStyle(fontSize: 14)),
          ),
          if (!isUser && !streaming && message.planChangeProposed != null) PlanChangePendingCard(message: message),
          if (!isUser && !streaming) MessageRatingWidget(messageId: message.id, initialRating: message.satisfactionRating),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({required this.controller, required this.hint, required this.sending, required this.onSend});
  final TextEditingController controller;
  final String hint;
  final bool sending;
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
                  onSubmitted: (_) => sending ? null : onSend(),
                  decoration: InputDecoration(hintText: hint, isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: AppSizes.minTapTarget,
                height: AppSizes.minTapTarget,
                // Disabled while a reply is streaming in; no spinner (the bubble shows progress).
                child: IconButton(
                  icon: const Icon(Icons.send),
                  color: AppColors.accent,
                  onPressed: sending ? null : onSend,
                ),
              ),
            ],
          ),
        ),
      );
}
