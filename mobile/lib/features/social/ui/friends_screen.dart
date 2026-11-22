// Friends (FR-049, FR-050): compare weekly scores, leaderboard, requests, invite by link or username.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/time_ago.dart';
import '../data/social_api.dart';
import 'social_widgets.dart';

/// Scores for the comparison chart: the user and the top 3 friends.
final _compareProvider = FutureProvider.autoDispose<Map<String, List<int>>>((ref) async {
  final board = await ref.watch(leaderboardProvider.future);
  final me = ref.watch(currentUserIdProvider);
  final ids = [if (me != null) me, ...board.where((e) => e.userId != me).take(3).map((e) => e.userId)];
  if (ids.length < 2) return const {};
  return ref.watch(socialApiProvider).weeklyScores(ids);
});

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(currentUserIdProvider);
    final board = ref.watch(leaderboardProvider);
    final requests = ref.watch(friendRequestsProvider).value ?? const [];
    final compare = ref.watch(_compareProvider).value ?? const {};
    final names = {for (final e in board.value ?? const <LeaderboardEntry>[]) e.userId: e.displayName};
    return Scaffold(
      appBar: AppBar(title: Text(l.friendsTitle), actions: [
        TextButton(key: const ValueKey('friends-add'), onPressed: () => _add(context, ref), child: Text(l.friendsAdd)),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.xl),
        children: [
          const ShareOptInCard(),
          if (requests.isNotEmpty) ...[
            Text(l.friendsRequests, style: Theme.of(context).textTheme.labelLarge),
            for (final r in requests)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: InitialsAvatar(name: r.displayName, color: AppColors.glacier),
                title: Text(r.displayName),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                      onPressed: () async {
                        await ref.read(socialApiProvider).remove(r.friendshipId);
                        ref.invalidate(friendRequestsProvider);
                      },
                      child: Text(l.friendsDecline)),
                  ElevatedButton(
                      onPressed: () async {
                        await ref.read(socialApiProvider).accept(r.friendshipId);
                        ref
                          ..invalidate(friendRequestsProvider)
                          ..invalidate(leaderboardProvider)
                          ..invalidate(feedProvider);
                      },
                      child: Text(l.friendsAccept)),
                ]),
              ),
            const SizedBox(height: AppSpacing.base),
          ],
          if (compare.length > 1) _CompareCard(series: compare, names: names, me: me),
          const SizedBox(height: AppSpacing.base),
          Text(l.friendsLeaderboard, style: Theme.of(context).textTheme.labelLarge),
          ...switch (board) {
            AsyncData(:final value) => [
                for (final (i, e) in value.indexed) _BoardRow(rank: i + 1, entry: e, mine: e.userId == me),
              ],
            AsyncError() => [Text(l.feedLoadError)],
            _ => [
                const Padding(padding: EdgeInsets.all(AppSpacing.lg), child: Center(child: CircularProgressIndicator()))
              ],
          },
          const SizedBox(height: AppSpacing.base),
          _InviteCard(onAdd: () => _add(context, ref)),
          const SizedBox(height: AppSpacing.base),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined, size: 16, color: AppColors.mist),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(l.friendsPrivacy, style: Theme.of(context).textTheme.bodySmall)),
          ]),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.friendsAddTitle),
        content: TextField(
          key: const ValueKey('friend-username'),
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: l.friendsUsernameHint, prefixText: '@'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancelButton)),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(l.friendsSendRequest)),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    String msg;
    try {
      await ref.read(socialApiProvider).addByUsername(name);
      msg = l.friendsRequestSent;
    } on UserNotFound {
      msg = l.friendsNotFound;
    } on Object {
      msg = l.feedLoadError;
    }
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.rank, required this.entry, required this.mine});
  final int rank;
  final LeaderboardEntry entry;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = entry.change;
    return Container(
      key: ValueKey('board-${entry.userId}'),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: mine
          ? BoxDecoration(color: AppColors.glacier.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16))
          : null,
      child: Row(children: [
        SizedBox(
            width: 30,
            child: Text('#$rank',
                style: TextStyle(fontWeight: FontWeight.w700, color: rank == 1 ? AppColors.mint : AppColors.mist))),
        InitialsAvatar(name: mine ? l.friendsYou : entry.displayName, color: friendColor(entry.userId), size: 42),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mine ? l.friendsYou : entry.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              entry.lastTrainedAt == null
                  ? l.friendsNeverTrained
                  : l.friendsLastTrained(timeAgo(l, entry.lastTrainedAt!, DateTime.now())),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (c != 0)
              Text(c > 0 ? l.friendsUpThisWeek(c) : l.friendsDownThisWeek(-c),
                  style: TextStyle(fontSize: 12.5, color: c > 0 ? AppColors.mint : AppColors.mist)),
          ]),
        ),
        ScoreRing(score: entry.score, color: rank == 1 ? AppColors.mint : AppColors.glacier),
      ]),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.series, required this.names, required this.me});
  final Map<String, List<int>> series;
  final Map<String, String> names;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ids = [if (series.containsKey(me)) me!, ...series.keys.where((k) => k != me)];
    final colors = {for (final (i, id) in ids.indexed) id: kFriendColors[i % kFriendColors.length]};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.friendsCompare, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(l.friendsCompareBody, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(spacing: AppSpacing.md, children: [
            for (final id in ids)
              Row(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 4, backgroundColor: colors[id]),
                const SizedBox(width: 4),
                Text(id == me ? l.friendsYou : (names[id] ?? ''), style: const TextStyle(fontSize: 12)),
              ]),
          ]),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 170,
            child: LineChart(LineChartData(
              gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.steel, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                topTitles: AxisTitles(),
                rightTitles: AxisTitles(),
                bottomTitles: AxisTitles(),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
              ),
              lineBarsData: [
                for (final id in ids.reversed)
                  LineChartBarData(
                    spots: [for (final (i, v) in series[id]!.indexed) FlSpot(i.toDouble(), v.toDouble())],
                    isCurved: true,
                    color: colors[id],
                    barWidth: 2.6,
                    dotData: FlDotData(checkToShowDot: (s, d) => s.x == d.spots.last.x),
                  ),
              ],
            )),
          ),
        ]),
      ),
    );
  }
}

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final me = ref.watch(myIdentityProvider).value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.friendsInvite, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(me?.username == null ? l.friendsInviteBody : l.friendsYourUsername(me!.username!),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                key: const ValueKey('share-link'),
                icon: const Icon(Icons.link),
                label: Text(l.friendsShareLink),
                onPressed: me == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: me.inviteLink.toString()));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.friendsLinkCopied)));
                        }
                      },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child:
                  OutlinedButton.icon(icon: const Icon(Icons.search), label: Text(l.friendsSearch), onPressed: onAdd),
            ),
          ]),
          if (me != null && me.username == null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: () => _setUsername(context, ref), child: Text(l.friendsSetUsername)),
          ],
        ]),
      ),
    );
  }

  Future<void> _setUsername(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final u = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.friendsSetUsername),
        content: TextField(
            controller: ctrl, decoration: InputDecoration(prefixText: '@', helperText: l.friendsUsernameRules)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancelButton)),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(l.profileEditSave)),
        ],
      ),
    );
    if (u == null || !context.mounted) return;
    String? msg;
    if (!isValidUsername(u)) {
      msg = l.friendsUsernameRules;
    } else {
      try {
        await ref.read(socialApiProvider).setUsername(u);
        ref.invalidate(myIdentityProvider);
      } on UsernameTaken {
        msg = l.friendsUsernameTaken;
      } on Object {
        msg = l.feedLoadError;
      }
    }
    if (msg != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
