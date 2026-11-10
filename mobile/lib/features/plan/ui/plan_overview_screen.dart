import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('My Plan')),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (plan) {
          if (plan == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No active plan.'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/onboarding/disclaimer'),
                    child: const Text('Generate a plan'),
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
                      Text(plan.name,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Week ${plan.currentWeek} of ${plan.weeksTotal}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      _PlanNotices(planId: plan.id),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final dayIndex = index;
                    final dayLabel = _days[dayIndex];
                    // Sessions would be fetched per day; simplified here
                    return _DayCard(
                      dayLabel: dayLabel,
                      dayNumber: dayIndex + 1,
                      weekNumber: plan.currentWeek,
                    );
                  },
                  childCount: 7,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.dayLabel,
    required this.dayNumber,
    required this.weekNumber,
  });

  final String dayLabel;
  final int dayNumber;
  final int weekNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Simplified: show rest-day placeholder; real implementation queries sessions
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.xs),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.base),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.charcoalElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(dayLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          title: const Text('Rest day'),
          subtitle: const Text('Recovery is part of the plan.'),
        ),
      ),
    );
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
              leading: const Icon(Icons.info_outline, color: AppColors.accent),
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
