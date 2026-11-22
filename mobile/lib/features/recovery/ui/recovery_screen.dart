// Muscle recovery (FR-051, Pro): body map, next workout's muscles, every other muscle.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/muscle_groups.dart';
import '../../../shared/widgets/muscle_figure.dart';
import '../../subscription/domain/entitlement_provider.dart';
import '../../workout/domain/live_session.dart';
import '../../workout/domain/workout_providers.dart';
import '../data/local_training_history.dart';
import '../domain/recovery.dart';

/// Map level for a recovery %: 3 = needs rest, 0 = fresh.
int recoveryLevel(int percent) => percent >= 100 ? 0 : (percent >= 88 ? 1 : (percent >= 75 ? 2 : 3));

Map<String, int> recoveryLevels(Map<String, MuscleRecovery> r) => {
      for (final e in r.entries)
        if (!e.value.ready) e.key: recoveryLevel(e.value.percent)
    };

/// Muscle groups of today's session, from the session's library muscles.
List<String> nextWorkoutGroups(TodayStatus? today) => switch (today) {
      TrainingDay(:final muscleGroups) => [
          for (final g in kMuscleGroups)
            if (muscleGroups.any((m) => muscleGroupOf(m) == g || m == g)) g,
        ],
      _ => const [],
    };

class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final rec = ref.watch(recoveryProvider).value ?? const {};
    final next = nextWorkoutGroups(ref.watch(todayStatusProvider).value);
    final levels = recoveryLevels(rec);
    final others = [
      ...rec.keys.where((g) => !next.contains(g)),
      ...kMuscleGroups.where((g) => !next.contains(g) && !rec.containsKey(g)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.recoveryTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.xl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.steel),
              gradient: const RadialGradient(
                  center: Alignment(0, -1), radius: 1.3, colors: [Color(0xFF1E2333), AppColors.mid]),
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                MuscleFigure(view: FigureView.front, groupLevels: levels, height: 240, semanticLabel: l.recoveryTitle),
                MuscleFigure(view: FigureView.back, groupLevels: levels, height: 240),
              ]),
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.base, children: [
                _Legend(color: const Color(0xFFDCE6FF), label: l.recoveryLegendRest),
                _Legend(color: const Color(0xFF6D86C8), label: l.recoveryLegendRecovering),
                _Legend(color: const Color(0xFF3A3F4E), label: l.recoveryLegendFresh),
              ]),
            ]),
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(l.recoveryNext, style: Theme.of(context).textTheme.labelLarge),
            for (final g in next) RecoveryRow(group: g, recovery: rec[g], lang: lang),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(l.recoveryOther, style: Theme.of(context).textTheme.labelLarge),
          for (final g in others) RecoveryRow(group: g, recovery: rec[g], lang: lang),
          const SizedBox(height: AppSpacing.base),
          Text(l.recoveryExplain, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class RecoveryRow extends StatelessWidget {
  const RecoveryRow({super.key, required this.group, required this.recovery, required this.lang});
  final String group;
  final MuscleRecovery? recovery;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pct = recovery?.percent ?? 100;
    final ready = pct >= 100;
    final when = recovery == null ? '' : DateFormat.E(lang).add_Hm().format(recovery!.readyAt);
    return Padding(
      key: ValueKey('recovery-$group'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(children: [
        MuscleTile(group: group, size: 52, level: ready ? 3 : 2),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(muscleGroupLabel(group, lang), style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(ready ? l.recoveryFresh : l.recoveryReadyAt(when), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 5,
                backgroundColor: AppColors.steel,
                valueColor: AlwaysStoppedAnimation(ready ? AppColors.mint : AppColors.glacier),
              ),
            ),
          ]),
        ),
        const SizedBox(width: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (ready ? AppColors.mint : AppColors.glacier).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(ready ? l.recoveryReady : '$pct%',
              style: TextStyle(fontWeight: FontWeight.w700, color: ready ? AppColors.mint : AppColors.glacier)),
        ),
      ]),
    );
  }
}

/// Recovery summary card (Home, Feed · You). Free users see it locked (paywall).
class RecoveryCard extends ConsumerWidget {
  const RecoveryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;
    final rec = ref.watch(recoveryProvider).value ?? const {};
    final levels = isPro ? recoveryLevels(rec) : const <String, int>{};
    final lowest = rec.values.where((r) => !r.ready).toList()..sort((a, b) => a.percent.compareTo(b.percent));
    final subtitle = !isPro
        ? l.recoveryPro
        : (lowest.isEmpty
            ? l.recoveryCardAllFresh
            : l.recoveryCardLowest(muscleGroupLabel(lowest.first.group, lang), lowest.first.percent));
    return Card(
      key: const ValueKey('recovery-card'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => isPro ? context.push('/recovery') : context.push('/paywall?feature=general'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            MuscleFigure(view: FigureView.front, groupLevels: levels, height: 84),
            MuscleFigure(view: FigureView.back, groupLevels: levels, height: 84),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.recoveryCardTitle.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: AppFonts.mono, fontSize: 11, letterSpacing: 1.2, color: AppColors.glacier)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            Icon(isPro ? Icons.chevron_right : Icons.lock_outline, color: AppColors.mist),
          ]),
        ),
      ),
    );
  }
}
