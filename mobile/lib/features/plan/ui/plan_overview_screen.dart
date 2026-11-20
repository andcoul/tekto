import 'package:tekto/features/plan/ui/adaptation_card.dart';
import 'package:tekto/features/coach/ui/coach_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/shared/utils/weight_units.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/models/exercise_model.dart';
import 'package:tekto/features/workout/domain/workout_providers.dart';
import 'package:tekto/features/workout/domain/live_session.dart';
import 'package:tekto/features/plan/ui/exercise_swap_sheet.dart';
import 'package:tekto/features/plan/domain/plan_week_provider.dart';
import 'package:tekto/core/di/providers.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/domain/onboarding_controller.dart';
import '../domain/plan_provider.dart';

class PlanOverviewScreen extends ConsumerWidget {
  const PlanOverviewScreen({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(activePlanProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(AppLocalizations.of(context).planTitle), actions: const [CoachButton(screen: 'plan_overview')]),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppLocalizations.of(context).commonLoadError)),
        data: (plan) {
          if (plan == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppLocalizations.of(context).planNone),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/onboarding/disclaimer'),
                    child: Text(AppLocalizations.of(context).planGenerate),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.base),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.name, style: Theme.of(context).textTheme.headlineMedium),
                      // Why this plan fits (FR-044).
                      if ((Localizations.localeOf(context).languageCode == 'fr' ? plan.rationaleFr : plan.rationaleEn)
                          case final rationale? when rationale.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(rationale, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                      // What changed this week and why (FR-027).
                      const AdaptationCard(),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).planWeekOf(plan.currentWeek, plan.weeksTotal),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      _PlanNotices(planId: plan.id),
                    ],
                  ),
                ),
              ),
              _WeekView(planId: plan.id, week: plan.currentWeek, dayLabels: _days),
            ],
          );
        },
      ),
    );
  }
}

/// This week's sessions with their exercises (US1 scenario 1), one card per day; any exercise
/// can be swapped here too, not only during a workout (FR-028, T138).
class _WeekView extends ConsumerWidget {
  const _WeekView({required this.planId, required this.week, required this.dayLabels});

  final String planId;
  final int week;
  final List<String> dayLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(planWeekProvider((planId: planId, week: week))).value ?? const [];
    final byDay = {for (final d in days) d.session.dayOfWeek: d};
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _DayCard(dayLabel: dayLabels[index], day: byDay[index + 1]),
        childCount: 7,
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.dayLabel, required this.day});

  final String dayLabel;
  final PlanDay? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fr = Localizations.localeOf(context).languageCode == 'fr';
    final badge = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(dayLabel, style: const TextStyle(fontWeight: FontWeight.w600))),
    );

    final d = day;
    if (d == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
        child: Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(AppSpacing.base),
            leading: badge,
            title: Text(AppLocalizations.of(context).planRestDay),
            subtitle: Text(AppLocalizations.of(context).planRestDayBody),
          ),
        ),
      );
    }

    final unit = ref.watch(userPrefsProvider).value?.unit ?? 'kg';
    final online = ref.watch(isOnlineProvider).value ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xs),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                badge,
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Text(fr ? d.session.nameFr : d.session.nameEn, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (d.session.estimatedMin case final min?)
                  Text('$min min', style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: AppSpacing.sm),
              for (final x in d.exercises)
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.exercise == null ? x.slot.exerciseSlug : (fr ? x.exercise!.nameFr : x.exercise!.nameEn)),
                        Text(
                          [
                            '${x.slot.sets} × ${x.slot.repsMin == x.slot.repsMax ? x.slot.repsMin : '${x.slot.repsMin}–${x.slot.repsMax}'}',
                            if ((x.slot.suggestedWeightKg ?? 0) > 0)
                              '${formatWeight(kgToUnit(x.slot.suggestedWeightKg!, unit))} $unit',
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: l.swapTitle,
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    // The swap is checked and applied by the server (Video Gate, Constitution IV).
                    onPressed: online ? () => _openSwap(context, ref, x.slot) : null,
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSwap(BuildContext context, WidgetRef ref, PlanExercise slot) async {
    final prefs = ref.read(userPrefsProvider).value ?? const UserPrefs();
    final chosen = await showModalBottomSheet<ExerciseModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExerciseSwapSheet(
        planExerciseId: slot.id,
        currentExerciseSlug: slot.exerciseSlug,
        userEquipment: prefs.equipment,
        userLimitations: prefs.limitations,
      ),
    );
    if (chosen == null) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(planRepositoryProvider).refreshActivePlan(userId);
    } on Object {
      // Applied on the server; the cache catches up on the next refresh.
    }
  }
}

/// Non-blocking cards from plan generation (FR-003b fallback, free 5–7 day cap). Dismissible,
/// never modal (Constitution VI). Shown for the plan just created during onboarding.
class _PlanNotices extends ConsumerStatefulWidget {
  const _PlanNotices({required this.planId});
  final String planId;

  @override
  ConsumerState<_PlanNotices> createState() => _PlanNoticesState();
}

class _PlanNoticesState extends ConsumerState<_PlanNotices> {
  final _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(onboardingControllerProvider).result;
    if (result == null || result.planId != widget.planId) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final messages = <String, String>{
      if (result.fallbackNotice) 'fallback': l10n.planFallbackNotice,
      if (result.notices.contains('free_plan_days_capped')) 'days': l10n.freePlanDaysCapped,
    }..removeWhere((key, _) => _dismissed.contains(key));

    return Column(
      children: [
        for (final MapEntry(:key, :value) in messages.entries)
          Card(
            margin: const EdgeInsets.only(top: AppSpacing.base),
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.glacier),
              title: Text(value),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => setState(() => _dismissed.add(key)),
              ),
            ),
          ),
      ],
    );
  }
}
