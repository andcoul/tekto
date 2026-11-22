// Profile tab (FR-053): identity, friends / support / streak / weight cards, workout heatmap,
// badges, then the user's details. Reads the device DB, so it works offline.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/muscle_groups.dart';
import '../../../shared/utils/weight_units.dart';
import '../../recovery/data/local_training_history.dart';
import '../../social/data/social_api.dart';
import '../../subscription/domain/entitlement_provider.dart';
import '../../workout/domain/workout_providers.dart';
import '../domain/profile_stats.dart';

class ProfileData {
  const ProfileData({
    required this.name,
    required this.workouts,
    required this.streak,
    required this.perWeek,
    required this.thisWeek,
    required this.weightKg,
    required this.levels,
    required this.badges,
    required this.focus,
  });
  final String name;
  final List<WorkoutDay> workouts;
  final int streak;
  final int perWeek;
  final int thisWeek;
  final double? weightKg;
  final Map<DateTime, int> levels;
  final List<BadgeDef> badges;
  final List<String> focus;
}

class ProfileYear extends Notifier<int> {
  @override
  int build() => DateTime.now().year;
  void set(int year) => state = year;
}

final profileYearProvider = NotifierProvider<ProfileYear, int>(ProfileYear.new);

final profileDataProvider = FutureProvider.autoDispose<ProfileData>((ref) async {
  final userId = ref.watch(currentUserIdProvider) ?? '';
  final h = ref.watch(localTrainingHistoryProvider);
  final now = ref.watch(clockProvider)();
  final year = ref.watch(profileYearProvider);
  final user = await h.user(userId);
  final workouts = await h.finishedWorkouts(userId);
  final perWeek = user?.daysPerWeek ?? 3;
  final friends = ref.watch(leaderboardProvider).value?.length ?? 1;
  final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  // Best streak = the longest run ending at any week; computed by replaying "now" at each week end.
  var best = streakWeeks(workouts, perWeek, now);
  for (final w in workouts) {
    final s = streakWeeks(workouts, perWeek, w.finishedAt);
    if (s > best) best = s;
  }
  final stats = BadgeStats(
    workouts: workouts.length,
    bestStreakWeeks: best,
    recordLifts: await h.recordLifts(userId),
    friends: friends - 1,
    totalVolumeKg: workouts.fold(0.0, (s, w) => s + w.volumeKg),
  );
  return ProfileData(
    name: user?.displayName ?? '',
    workouts: workouts,
    streak: streakWeeks(workouts, perWeek, now),
    perWeek: perWeek,
    thisWeek: workouts.where((w) => !w.finishedAt.isBefore(weekStart)).length,
    weightKg: await h.latestBodyWeightKg(userId),
    levels: heatmapLevels(workouts, year),
    badges: earnedBadges(stats),
    focus: user == null ? const [] : (jsonDecode(user.focusMuscles) as List).cast<String>(),
  );
});

String badgeLabel(AppLocalizations l, BadgeDef b) => switch (b.kind) {
      BadgeKind.streak => l.badgeStreak(b.threshold.toInt()),
      BadgeKind.workouts => l.badgeWorkouts(b.threshold.toInt()),
      BadgeKind.record => l.badgeRecord(switch (b.lift) {
          'squat' => l.liftSquat.toLowerCase(),
          'bench_press' => l.liftBenchPress.toLowerCase(),
          'deadlift' => l.liftDeadlift.toLowerCase(),
          'overhead_press' => l.liftOverheadPress.toLowerCase(),
          'row' => l.liftRow.toLowerCase(),
          _ => l.liftHipThrust.toLowerCase(),
        }),
      BadgeKind.friends => b.threshold == 1 ? l.badgeFirstFriend : l.badgeFriends(b.threshold.toInt()),
      BadgeKind.volume => l.badgeVolume((b.threshold / 1000).round()),
    };

IconData badgeIcon(BadgeKind k) => switch (k) {
      BadgeKind.streak => Icons.local_fire_department_outlined,
      BadgeKind.workouts => Icons.fitness_center,
      BadgeKind.record => Icons.emoji_events_outlined,
      BadgeKind.friends => Icons.group_outlined,
      BadgeKind.volume => Icons.auto_awesome,
    };

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final data = ref.watch(profileDataProvider).value;
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;
    final unit = ref.watch(userPrefsProvider).value?.unit ?? 'kg';
    final friends = (ref.watch(leaderboardProvider).value?.length ?? 1) - 1;
    final year = ref.watch(profileYearProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navProfile),
        actions: [
          IconButton(
              tooltip: l.settingsTitle,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings')),
        ],
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.base, 0, AppSpacing.base, MediaQuery.paddingOf(context).bottom + AppSpacing.base),
              children: [
                Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.deep,
                    child: Text(data.name.isEmpty ? '·' : data.name.characters.first.toUpperCase(),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data.name.isEmpty ? l.profileNoName : data.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      Row(children: [
                        Text(l.profileWorkouts(data.workouts.length), style: Theme.of(context).textTheme.bodySmall),
                        if (isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.glacier, borderRadius: BorderRadius.circular(6)),
                            child: const Text('PRO',
                                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: AppColors.ink)),
                          ),
                        ],
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: AppSpacing.base),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.45,
                  children: [
                    _HubCard(
                        key: const ValueKey('hub-friends'),
                        icon: Icons.group_outlined,
                        title: l.profileFriends(friends),
                        subtitle: l.profileFriendsSub,
                        onTap: () => context.push('/friends')),
                    _HubCard(
                        key: const ValueKey('hub-support'),
                        icon: Icons.support_agent_outlined,
                        title: l.supportTitle,
                        subtitle: l.profileSupportSub,
                        onTap: () => context.push('/support')),
                    _HubCard(
                        icon: Icons.local_fire_department_outlined,
                        title: l.profileStreak(data.streak),
                        subtitle: l.profileStreakSub(data.thisWeek, data.perWeek)),
                    _HubCard(
                        icon: Icons.monitor_weight_outlined,
                        title: data.weightKg == null ? '—' : '${formatWeight(kgToUnit(data.weightKg!, unit))} $unit',
                        subtitle: l.profileMeasurements,
                        onTap: () => context.push('/progress')),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
                _HeatmapCard(
                    levels: data.levels,
                    year: year,
                    count: data.workouts.where((w) => w.finishedAt.year == year).length,
                    onYear: (y) => ref.read(profileYearProvider.notifier).set(y)),
                const SizedBox(height: AppSpacing.base),
                _BadgesCard(earned: data.badges),
                const SizedBox(height: AppSpacing.base),
                Card(
                  child: Column(children: [
                    ListTile(
                      title: Text(l.profileFocus),
                      subtitle: Text(data.focus.isEmpty
                          ? l.profileFocusNone
                          : data.focus.map((g) => muscleGroupLabel(g, lang)).join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/profile'),
                    ),
                    ListTile(
                      title: Text(l.profileTraining),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/settings/profile'),
                    ),
                    ListTile(
                      title: Text(l.planTitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/plan'),
                    ),
                  ]),
                ),
              ],
            ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({super.key, required this.icon, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: AppColors.glacier),
                const Spacer(),
                if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.mist),
              ]),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: 2),
            ]),
          ),
        ),
      );
}

const _heat = [Color(0xFF23262F), Color(0x599DB8FF), Color(0x999DB8FF), Color(0xD19DB8FF), Color(0xFFDCE6FF)];

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.levels, required this.year, required this.count, required this.onYear});
  final Map<DateTime, int> levels;
  final int year;
  final int count;
  final ValueChanged<int> onYear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final end = year == now.year ? DateTime(now.year, now.month, now.day) : DateTime(year, 12, 31);
    // The last 22 weeks up to [end], Monday-first columns.
    final lastMonday = end.subtract(Duration(days: end.weekday - 1));
    final first = lastMonday.subtract(const Duration(days: 7 * 21));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(l.profileWorkouts(count), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const Spacer(),
            PopupMenuButton<int>(
              initialValue: year,
              onSelected: onYear,
              itemBuilder: (_) =>
                  [for (var y = now.year; y >= now.year - 3; y--) PopupMenuItem(value: y, child: Text('$y'))],
              child: Chip(label: Text('$year')),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var w = 0; w < 22; w++)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Column(children: [
                    for (var d = 0; d < 7; d++)
                      Builder(builder: (_) {
                        final day = first.add(Duration(days: w * 7 + d));
                        final future = day.isAfter(end);
                        return Container(
                          width: 11,
                          height: 11,
                          margin: const EdgeInsets.only(bottom: 3),
                          decoration: BoxDecoration(
                            color: future ? Colors.transparent : _heat[levels[day] ?? 0],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                  ]),
                ),
            ]),
          ),
          Row(children: [
            Text(l.profileVolume, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(l.profileLess, style: Theme.of(context).textTheme.bodySmall),
            for (final c in _heat)
              Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            Text(l.profileMore, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.earned});
  final List<BadgeDef> earned;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final show = earned.reversed.take(3).toList();
    const colors = {
      BadgeKind.streak: AppColors.glacier,
      BadgeKind.workouts: Color(0xFFC9B6FF),
      BadgeKind.record: AppColors.mint,
      BadgeKind.friends: Color(0xFF8FD3FF),
      BadgeKind.volume: AppColors.glacier,
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => GridView.count(
            crossAxisCount: 4,
            padding: const EdgeInsets.all(AppSpacing.base),
            children: [
              for (final b in kBadges)
                Opacity(
                  opacity: earned.contains(b) ? 1 : 0.3,
                  child: Column(children: [
                    Icon(badgeIcon(b.kind), color: colors[b.kind]),
                    const SizedBox(height: 4),
                    Text(badgeLabel(l, b),
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 11), maxLines: 2),
                  ]),
                ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(l.profileBadges, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const Spacer(),
              Text(l.profileBadgesCount(earned.length, kBadges.length), style: Theme.of(context).textTheme.bodySmall),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.mist),
            ]),
            const SizedBox(height: AppSpacing.md),
            if (show.isEmpty)
              Text(l.profileBadgesNone, style: Theme.of(context).textTheme.bodySmall)
            else
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                for (final b in show)
                  SizedBox(
                    width: 96,
                    child: Column(children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                              center: const Alignment(-0.3, -0.4),
                              colors: [colors[b.kind]!.withValues(alpha: 0.35), AppColors.mid]),
                          border: Border.all(color: colors[b.kind]!.withValues(alpha: 0.55), width: 2),
                        ),
                        child: Icon(badgeIcon(b.kind), color: colors[b.kind]),
                      ),
                      const SizedBox(height: 6),
                      Text(badgeLabel(l, b),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ]),
          ]),
        ),
      ),
    );
  }
}
