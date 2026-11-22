import '../../core/l10n/gen/app_localizations.dart';

/// "6 h ago", "2 d ago"… for the feed and leaderboard.
String timeAgo(AppLocalizations l, DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 60) return l.timeAgoMinutes(d.inMinutes.clamp(1, 59));
  if (d.inHours < 24) return l.timeAgoHours(d.inHours);
  return l.timeAgoDays(d.inDays);
}
