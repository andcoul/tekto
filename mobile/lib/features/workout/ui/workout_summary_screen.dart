import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState
    extends ConsumerState<WorkoutSummaryScreen> {
  int _effortRating = 7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout complete')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SummaryCard(
              totalVolumeKg: 2450,
              exerciseCount: 5,
              prCount: 1,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('How hard was that session?',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text('$_effortRating RPE',
                    style: Theme.of(context).textTheme.headlineMedium),
                Expanded(
                  child: Slider(
                    value: _effortRating.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: AppColors.accent,
                    onChanged: (v) =>
                        setState(() => _effortRating = v.round()),
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Finish'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalVolumeKg,
    required this.exerciseCount,
    required this.prCount,
  });

  final int totalVolumeKg;
  final int exerciseCount;
  final int prCount;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Volume', value: '${totalVolumeKg}kg'),
              _Stat(label: 'Exercises', value: '$exerciseCount'),
              _Stat(
                label: 'PRs',
                value: '$prCount',
                highlight: prCount > 0,
              ),
            ],
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: highlight ? AppColors.pr : null,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      );
}
