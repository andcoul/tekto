import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../plan/domain/plan_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(activePlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.base),
          children: [
            planAsync.when(
              loading: () => const _SessionCardSkeleton(),
              error: (e, _) => Text('Error loading plan: $e'),
              data: (plan) {
                if (plan == null) {
                  return _NoPlaceholder(
                    onGenerate: () =>
                        context.go('/onboarding/disclaimer'),
                  );
                }
                // In a real implementation we'd resolve today's session;
                // simplified placeholder below
                return _TodaySessionCard(
                  sessionName: 'Full Body A',
                  muscleTargets: const ['Chest', 'Back', 'Legs'],
                  estimatedMin: 55,
                  onStart: () => context.go('/workout/placeholder-session-id'),
                );
              },
            ),
            const SizedBox(height: AppSpacing.base),
            const _QuickAccessRow(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Plan'),
          NavigationDestination(
              icon: Icon(Icons.library_books_outlined), label: 'Library'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: 'Progress'),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 0: break;
            case 1: context.go('/plan');
            case 2: context.go('/library');
            case 3: context.go('/progress');
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
  final int estimatedMin;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sessionName,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(muscleTargets.join(' · '),
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 16, color: AppColors.onDarkSecondary),
                      const SizedBox(width: 4),
                      Text('$estimatedMin min',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start workout'),
              ),
            ],
          ),
        ),
      );
}

class _NoPlaceholder extends StatelessWidget {
  const _NoPlaceholder({required this.onGenerate});
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const Icon(Icons.fitness_center,
                  size: 48, color: AppColors.onDarkSecondary),
              const SizedBox(height: AppSpacing.sm),
              Text('No active plan',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Generate your first AI training plan.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.base),
              ElevatedButton(
                onPressed: onGenerate,
                child: const Text('Generate a plan'),
              ),
            ],
          ),
        ),
      );
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
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _QuickButton(
              icon: Icons.library_books_outlined,
              label: 'Exercises',
              onTap: () => context.push('/library'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickButton(
              icon: Icons.chat_bubble_outline,
              label: 'Coach',
              onTap: () => context.push('/coach'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickButton(
              icon: Icons.bar_chart_outlined,
              label: 'Progress',
              onTap: () => context.push('/progress'),
            ),
          ),
        ],
      );
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
          child: Column(
            children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
}
