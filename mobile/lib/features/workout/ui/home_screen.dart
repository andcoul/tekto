import 'package:tekto/features/coach/ui/coach_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/live_session.dart';
import '../domain/workout_providers.dart';

/// "lower_back" → "Lower back". Muscle tags are shown as-is in both languages for now,
/// like the library (tracked for the T094 localization audit).
String muscleLabel(String tag) {
  final words = tag.replaceAll('_', ' ');
  return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
}

/// Home (FR-006): today's planned session with duration and target muscles, read
/// from the device cache so it shows offline.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final today = ref.watch(todayStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: [
          const CoachButton(screen: 'home'),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: l.settingsTitle,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            switch (today) {
              AsyncData(value: final TrainingDay s) => _TodaySessionCard(
                  sessionName: s.name(lang),
                  muscleTargets: s.muscleGroups.map(muscleLabel).toList(),
                  estimatedMin: s.estimatedMin,
                  onStart: () => context.go('/workout/${s.sessionId}'),
                ),
              AsyncData(value: RestDay()) => const _RestDayCard(),
              AsyncData(value: NoActivePlan()) => _NoPlanCard(onGenerate: () => context.go('/onboarding/disclaimer')),
              AsyncError(:final error) => Text('$error'),
              _ => const _SessionCardSkeleton(),
            },
            const SizedBox(height: AppSpacing.base),
            const _QuickAccessRow(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l.navHome),
          NavigationDestination(icon: const Icon(Icons.fitness_center), label: l.navPlan),
          NavigationDestination(icon: const Icon(Icons.library_books_outlined), label: l.navLibrary),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), label: l.navProgress),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 1:
              context.go('/plan');
            case 2:
              context.go('/library');
            case 3:
              context.go('/progress');
          }
        },
        selectedIndex: 0,
      ),
    );
  }
}

class _TodaySessionCard extends StatelessWidget {
  const _TodaySessionCard({
    required this.sessionName,
    required this.muscleTargets,
    required this.estimatedMin,
    required this.onStart,
  });

  final String sessionName;
  final List<String> muscleTargets;
  final int? estimatedMin;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sessionName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(muscleTargets.join(' · '), style: theme.textTheme.bodyMedium),
                ]),
              ),
              if (estimatedMin != null)
                Row(children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.onDarkSecondary),
                  const SizedBox(width: 4),
                  Text(l.homeEstimatedMin(estimatedMin!), style: theme.textTheme.bodyMedium),
                ]),
            ]),
            const SizedBox(height: AppSpacing.base),
            SizedBox(
              height: AppSizes.minTapTarget,
              child: ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(l.homeStartWorkout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(children: [
          const Icon(Icons.self_improvement, size: 48, color: AppColors.onDarkSecondary),
          const SizedBox(height: AppSpacing.sm),
          Text(l.homeRestDay, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l.homeRestDaySubtitle, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _NoPlanCard extends StatelessWidget {
  const _NoPlanCard({required this.onGenerate});
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(children: [
          const Icon(Icons.fitness_center, size: 48, color: AppColors.onDarkSecondary),
          const SizedBox(height: AppSpacing.sm),
          Text(l.homeNoPlanTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(l.homeNoPlanSubtitle, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            height: AppSizes.minTapTarget,
            child: OutlinedButton(onPressed: onGenerate, child: Text(l.homeBuildPlan)),
          ),
        ]),
      ),
    );
  }
}

class _SessionCardSkeleton extends StatelessWidget {
  const _SessionCardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.charcoalSurface,
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
}

class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(children: [
      Expanded(
        child: _QuickButton(icon: Icons.library_books_outlined, label: l.homeExercises, onTap: () => context.push('/library')),
      ),
      const SizedBox(width: 8),
      Expanded(child: _QuickButton(icon: Icons.chat_bubble_outline, label: l.homeCoach, onTap: () => openCoach(context, screen: 'home'))),
      const SizedBox(width: 8),
      Expanded(
        child: _QuickButton(icon: Icons.bar_chart_outlined, label: l.homeProgress, onTap: () => context.push('/progress')),
      ),
    ]);
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
          decoration: BoxDecoration(
            color: AppColors.charcoalSurface,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          ),
          child: Column(children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      );
}
