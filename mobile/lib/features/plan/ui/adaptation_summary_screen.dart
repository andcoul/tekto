import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/features/plan/domain/adaptation_provider.dart';

/// Shown automatically after a week is completed.
///
/// Lists all exercises that changed with old → new value and a reason card.
/// "Got it" CTA advances to Week N+1 view.
class AdaptationSummaryScreen extends StatelessWidget {
  const AdaptationSummaryScreen({
    super.key,
    required this.summary,
  });

  final AdaptationSummary summary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Week ${summary.week} complete'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: summary.events.isEmpty
                ? const _MaintainMessage()
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    itemCount: summary.events.length,
                    itemBuilder: (context, index) =>
                        _AdaptationCard(event: summary.events[index]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ElevatedButton(
              onPressed: () => context.go('/plan'),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptationCard extends StatelessWidget {
  const _AdaptationCard({required this.event});
  final AdaptationEvent event;

  @override
  Widget build(BuildContext context) {
    final isWeight = event.field == 'suggested_weight_kg';
    final unit = isWeight ? 'kg' : 'reps max';
    final direction = event.newValue > event.oldValue ? '↑' : '↓';
    final color = event.newValue >= event.oldValue ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '$direction ${event.oldValue.toStringAsFixed(isWeight ? 1 : 0)} → ${event.newValue.toStringAsFixed(isWeight ? 1 : 0)} $unit',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              event.reasonEn,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onDarkSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintainMessage extends StatelessWidget {
  const _MaintainMessage();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pause_circle_outline,
                  size: 64, color: AppColors.onDarkSecondary),
              const SizedBox(height: AppSpacing.base),
              Text(
                'No changes this week',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your plan stays the same — keep showing up!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onDarkSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
