import 'package:flutter/material.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/coach/ui/coach_screen.dart';

/// Opens the AI coach as a slide-up sheet over the current screen (FR-016, T110), with the
/// screen's context so answers can refer to what the user is looking at. The screen stays
/// underneath; closing the sheet returns to it unchanged (a workout keeps running).
Future<void> openCoach(BuildContext context, {required String screen, String? exerciseSlug, String? sessionId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Padding(
      // Keeps the input above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: CoachScreen(screenContext: screen, exerciseSlug: exerciseSlug, sessionId: sessionId),
    ),
  );
}

/// The coach entry point placed in the app bar of every primary screen. An app-bar icon never
/// covers a screen's primary action (Constitution VI), including during a live workout.
class CoachButton extends StatelessWidget {
  const CoachButton({super.key, required this.screen, this.exerciseSlug, this.sessionId});

  /// Screen name sent as `context.screen` (`home`, `plan_overview`, `library`, `exercise_detail`,
  /// `progress`, `settings`, `live_workout`).
  final String screen;
  final String? exerciseSlug;
  final String? sessionId;

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.chat_bubble_outline),
        tooltip: AppLocalizations.of(context).homeCoach,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: () => openCoach(context, screen: screen, exerciseSlug: exerciseSlug, sessionId: sessionId),
      );
}
