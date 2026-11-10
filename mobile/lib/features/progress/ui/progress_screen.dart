import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/core/theme/app_theme.dart';

/// Progress screen — History, Records, Volume tabs.
///
/// Route: /progress
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Progress'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'History'),
              Tab(text: 'Records'),
              Tab(text: 'Volume'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HistoryTab(),
            _RecordsTab(),
            _VolumeTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History Tab — reverse-chronological workout log list
// ---------------------------------------------------------------------------

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // In full implementation, watch workoutHistoryProvider
    // For now, scaffold with placeholder data
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: 0,
      itemBuilder: (context, index) => const _WorkoutHistoryRow(),
    );
  }
}

class _WorkoutHistoryRow extends StatelessWidget {
  const _WorkoutHistoryRow();

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          title: const Text('Push Day A'),
          subtitle: const Text('Nov 9 · 8 sets · 2,450 kg'),
          children: const [
            ListTile(
              title: Text('Bench Press'),
              trailing: Text('3×5 @ 80 kg'),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Records Tab — personal records grouped by muscle
// ---------------------------------------------------------------------------

class _RecordsTab extends ConsumerWidget {
  const _RecordsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Scaffold — full implementation watches personalRecordsProvider
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: const [
        _MuscleGroupSection(muscle: 'Chest'),
        _MuscleGroupSection(muscle: 'Back'),
        _MuscleGroupSection(muscle: 'Legs'),
      ],
    );
  }
}

class _MuscleGroupSection extends StatelessWidget {
  const _MuscleGroupSection({required this.muscle});
  final String muscle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                left: 8, top: AppSpacing.base, bottom: 4),
            child: Text(
              muscle,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.onDarkSecondary,
                  ),
            ),
          ),
          // placeholder row
          ListTile(
            title: const Text('Bench Press'),
            subtitle: const Text('e1RM: 116.7 kg'),
            trailing: Text(
              '100 kg × 5',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Volume Tab — bar chart of weekly volume (last 8 weeks)
// ---------------------------------------------------------------------------

class _VolumeTab extends ConsumerWidget {
  const _VolumeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Placeholder data — full implementation watches weeklyVolumeProvider
    final data = _sampleVolumeData();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly volume (kg)',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.base),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 6000,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => Text(
                        '${(value / 1000).toStringAsFixed(1)}k',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onDarkSecondary,
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        'W${value.toInt() + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onDarkSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  horizontalInterval: 1500,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.charcoalElevated,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value,
                        color: AppColors.accent,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<double> _sampleVolumeData() => [
        2100,
        2450,
        1800,
        2800,
        3100,
        2600,
        3200,
        2900,
      ];
}
