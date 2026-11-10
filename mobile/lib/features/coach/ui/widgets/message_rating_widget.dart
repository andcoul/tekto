import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/coach/data/coach_message_repository.dart';

/// Thumbs-up / thumbs-down rating for an assistant coach message.
///
/// - Shown on each assistant message bubble after it finishes rendering.
/// - Each message can only be rated once (button disables after tap).
/// - Rating is optional — never prompted, never required.
/// - Tapping PATCH /coach_messages sets satisfaction_rating = true|false.
/// - Tracks SC-011 target (≥85% thumbs-up).
class MessageRatingWidget extends ConsumerStatefulWidget {
  const MessageRatingWidget({super.key, required this.messageId});

  final String messageId;

  @override
  ConsumerState<MessageRatingWidget> createState() =>
      _MessageRatingWidgetState();
}

class _MessageRatingWidgetState extends ConsumerState<MessageRatingWidget> {
  bool? _rated; // null = not rated; true = thumbs up; false = thumbs down

  @override
  Widget build(BuildContext context) {
    if (_rated != null) {
      // Show static confirmation icon after rating
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Icon(
          _rated! ? Icons.thumb_up : Icons.thumb_down,
          size: 14,
          color: AppColors.onDarkSecondary,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            icon: const Icon(Icons.thumb_up_outlined, size: 14),
            color: AppColors.onDarkSecondary,
            padding: EdgeInsets.zero,
            tooltip: 'Helpful',
            onPressed: () => _rate(thumbsUp: true),
          ),
        ),
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            icon: const Icon(Icons.thumb_down_outlined, size: 14),
            color: AppColors.onDarkSecondary,
            padding: EdgeInsets.zero,
            tooltip: 'Not helpful',
            onPressed: () => _rate(thumbsUp: false),
          ),
        ),
      ],
    );
  }

  Future<void> _rate({required bool thumbsUp}) async {
    setState(() => _rated = thumbsUp);
    try {
      final repo = ref.read(coachMessageRepositoryProvider);
      await repo.rateSatisfaction(widget.messageId, thumbsUp: thumbsUp);
    } catch (_) {
      // Ratings are optional — silently ignore failures
    }
  }
}

/// Provider — resolved in core/di/providers.dart.
final coachMessageRepositoryProvider =
    Provider<CoachMessageRepository>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});
