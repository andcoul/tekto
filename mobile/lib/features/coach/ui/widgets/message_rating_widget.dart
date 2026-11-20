import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/coach/data/coach_message_repository.dart';

/// Thumbs-up / thumbs-down rating for a finished assistant coach message (SC-011, T111).
///
/// - One rating per message: the buttons are replaced by the chosen thumb after a tap, and a
///   message that was already rated ([initialRating]) shows its thumb only.
/// - Optional: never prompted or required; a failed save is ignored.
/// - Saved on the device and queued for the server (`coach_messages.satisfaction_rating`).
/// - Gym-sized tap targets (≥ 48 dp, Constitution VI) with localized labels.
class MessageRatingWidget extends ConsumerStatefulWidget {
  const MessageRatingWidget({super.key, required this.messageId, this.initialRating});

  final String messageId;

  /// The stored rating, if the message was rated before (true = thumbs up).
  final bool? initialRating;

  @override
  ConsumerState<MessageRatingWidget> createState() => _MessageRatingWidgetState();
}

class _MessageRatingWidgetState extends ConsumerState<MessageRatingWidget> {
  late bool? _rated = widget.initialRating;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_rated != null) {
      return Semantics(
        label: _rated! ? l.coachRateHelpful : l.coachRateNotHelpful,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(_rated! ? Icons.thumb_up : Icons.thumb_down, size: 16, color: AppColors.mist),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RateButton(
          icon: Icons.thumb_up_outlined,
          tooltip: l.coachRateHelpful,
          onPressed: () => _rate(thumbsUp: true),
        ),
        _RateButton(
          icon: Icons.thumb_down_outlined,
          tooltip: l.coachRateNotHelpful,
          onPressed: () => _rate(thumbsUp: false),
        ),
      ],
    );
  }

  Future<void> _rate({required bool thumbsUp}) async {
    setState(() => _rated = thumbsUp);
    try {
      await ref.read(coachMessageRepositoryProvider).rateSatisfaction(widget.messageId, thumbsUp: thumbsUp);
    } catch (_) {
      // Ratings are optional — a failed save is not shown to the user.
    }
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon, size: 18),
        color: AppColors.mist,
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onPressed,
      );
}
