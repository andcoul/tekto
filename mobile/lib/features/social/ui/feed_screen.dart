// Feed tab (FR-048, FR-049): Friends (friends' workouts with reactions, weekly rank) and You
// (the user's own progress, headed by recovery).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/time_ago.dart';
import '../../../shared/utils/weight_units.dart';
import '../../../shared/widgets/muscle_figure.dart';
import '../../coach/ui/coach_launcher.dart';
import '../../progress/ui/progress_screen.dart';
import '../../recovery/ui/recovery_screen.dart';
import '../../workout/domain/workout_providers.dart';
import '../data/social_api.dart';
import 'social_widgets.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, this.initialYou = false});
  final bool initialYou;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late bool _you = widget.initialYou;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.feedTitle),
        actions: [
          IconButton(
            key: const ValueKey('open-friends'),
            tooltip: l.friendsTitle,
            icon: const Icon(Icons.group_outlined),
            onPressed: () => context.push('/friends'),
          ),
          const CoachButton(screen: 'feed'),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(l.feedFriends)),
                ButtonSegment(value: true, label: Text(l.feedYou)),
              ],
              selected: {_you},
              onSelectionChanged: (s) => setState(() => _you = s.first),
            ),
          ),
        ),
      ),
      body: _you ? const _YouView() : const _FriendsView(),
    );
  }
}

class _YouView extends StatelessWidget {
  const _YouView();
  @override
  Widget build(BuildContext context) => const Column(children: [
        Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.sm, AppSpacing.base, 0), child: RecoveryCard()),
        Expanded(child: ProgressScreen(embedded: true)),
      ]);
}

class _FriendsView extends ConsumerWidget {
  const _FriendsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final posts = ref.watch(feedProvider);
    final board = ref.watch(leaderboardProvider).value ?? const [];
    final me = ref.watch(currentUserIdProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(feedProvider);
        ref.invalidate(leaderboardProvider);
        await ref.read(feedProvider.future);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.sm, AppSpacing.base, MediaQuery.paddingOf(context).bottom + AppSpacing.base),
        children: [
          if (board.length > 1) _RankCard(board: board, me: me),
          ...switch (posts) {
            AsyncData(:final value) when value.isEmpty => [_EmptyFeed(l: l)],
            AsyncData(:final value) => [for (final p in value) PostCard(post: p, mine: p.userId == me)],
            AsyncError() => [Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: Text(l.feedLoadError))],
            _ => [
                const Padding(padding: EdgeInsets.all(AppSpacing.xl), child: Center(child: CircularProgressIndicator()))
              ],
          },
        ],
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.board, required this.me});
  final List<LeaderboardEntry> board;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final i = board.indexWhere((e) => e.userId == me);
    final mine = i < 0 ? null : board[i];
    final ahead = i > 0 ? board[i - 1] : null;
    return Card(
      key: const ValueKey('rank-card'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/friends'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            ScoreRing(score: mine?.score ?? 0),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.feedThisWeek.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 1.2, color: AppColors.glacier)),
                Text(l.feedRank(i + 1, board.length), style: const TextStyle(fontWeight: FontWeight.w600)),
                if (ahead != null && mine != null)
                  Text(l.feedBehind(ahead.score - mine.score, ahead.displayName),
                      style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mist),
          ]),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.l});
  final AppLocalizations l;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(children: [
          const Icon(Icons.group_outlined, size: 40, color: AppColors.glacier),
          const SizedBox(height: AppSpacing.md),
          Text(l.feedEmpty, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(l.feedEmptyBody, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.base),
          ElevatedButton(onPressed: () => context.push('/friends'), child: Text(l.friendsAdd)),
        ]),
      );
}

class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, required this.mine});
  final FeedPost post;
  final bool mine;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late String? _mine = widget.post.myReaction;
  late Map<String, int> _counts = Map.of(widget.post.reactions);

  Future<void> _react(String emoji) async {
    final before = (_mine, Map.of(_counts));
    final next = _mine == emoji ? null : emoji;
    setState(() {
      if (_mine != null) _counts[_mine!] = (_counts[_mine!] ?? 1) - 1;
      if (next != null) _counts[next] = (_counts[next] ?? 0) + 1;
      _mine = next;
    });
    try {
      await ref.read(socialApiProvider).react(widget.post.workoutLogId, next);
    } on Object {
      if (mounted) {
        setState(() {
          _mine = before.$1;
          _counts = before.$2;
        }); // offline: undo
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final p = widget.post;
    final unit = ref.watch(userPrefsProvider).value?.unit ?? 'kg';
    final levels = p.groupLevels;
    final back = levels.keys.any((g) => (kGroupParts[g]?[FigureView.back] ?? const []).isNotEmpty) &&
        !levels.keys.any((g) => (kGroupParts[g]?[FigureView.front] ?? const []).isNotEmpty);
    return Card(
      key: ValueKey('post-${p.workoutLogId}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            InitialsAvatar(name: widget.mine ? l.friendsYou : p.displayName, color: friendColor(p.userId)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.mine ? l.friendsYou : p.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                    '${timeAgo(l, p.finishedAt, DateTime.now())} · ${lang == 'fr' ? p.sessionNameFr : p.sessionNameEn}',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.steel),
                gradient:
                    const RadialGradient(center: Alignment(0, -0.5), colors: [Color(0xFF232838), Color(0xFF14161C)]),
              ),
              child: MuscleFigure(view: back ? FigureView.back : FigureView.front, groupLevels: levels, height: 140),
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Stat(label: l.feedTime, value: l.feedMinutes(p.durationMin)),
                _Stat(label: l.feedVolume, value: '${formatWeight(kgToUnit(p.volumeKg, unit))} $unit'),
                _Stat(label: l.feedSets, value: '${p.setCount}'),
              ]),
            ),
          ]),
          if (p.recordSlugs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration:
                  BoxDecoration(color: AppColors.mint.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.emoji_events_outlined, size: 16, color: AppColors.mint),
                const SizedBox(width: 8),
                Text(l.feedRecords(p.recordSlugs.length), style: const TextStyle(color: AppColors.mint)),
              ]),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, children: [
            for (final e in kReactions)
              ChoiceChip(
                key: ValueKey('react-${p.workoutLogId}-$e'),
                label: Text('$e ${_counts[e] ?? 0}'),
                selected: _mine == e,
                onSelected: widget.mine ? null : (_) => _react(e),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style:
                  const TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 1.1, color: AppColors.mist)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        ]),
      );
}
