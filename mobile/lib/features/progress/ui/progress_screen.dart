import 'package:tekto/features/coach/ui/coach_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/muscle_labels.dart';
import '../../../shared/utils/weight_units.dart';
import '../../workout/domain/workout_providers.dart';
import '../data/progress_repository.dart';
import '../domain/progress_providers.dart';

/// Progress (FR-039–FR-041, T119): history, records, weekly volume and e1RM trends, body weight.
/// Reads only the device DB, so it works offline. Free users see the last 4 weeks and a
/// non-blocking Pro card; Pro users see everything plus muscle balance.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(progressDataProvider);
    final unit = ref.watch(userPrefsProvider).value?.unit ?? 'kg';
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.progressTitle),
          actions: const [CoachButton(screen: 'progress')],
          bottom: TabBar(isScrollable: true, tabs: [
            Tab(text: l.progressTabHistory),
            Tab(text: l.progressTabRecords),
            Tab(text: l.progressTabVolume),
            Tab(text: l.progressTabBodyWeight),
          ]),
        ),
        body: switch (data) {
          AsyncData(value: final p?) => TabBarView(children: [
              _HistoryTab(p, unit),
              _RecordsTab(p, unit),
              _VolumeTab(p, unit),
              _BodyWeightTab(p, unit),
            ]),
          AsyncError(:final error) => Center(child: Text('$error')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

String _weight(double kg, String unit) => '${formatWeight(kgToUnit(kg, unit))} $unit';

class _ProCard extends StatelessWidget {
  const _ProCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.auto_awesome, color: AppColors.glacier),
        title: Text(l.progressProCard),
        trailing: TextButton(onPressed: () => context.push('/paywall'), child: Text(l.progressProCardAction)),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab(this.p, this.unit);
  final ProgressData p;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final date = DateFormat.yMMMEd(lang);
    return ListView(padding: const EdgeInsets.all(AppSpacing.base), children: [
      if (p.limited) ...[
        Text(l.progressLimited, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (p.history.isEmpty) Text(l.progressNoHistory),
      for (final h in p.history)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(lang == 'fr' ? h.sessionNameFr : h.sessionNameEn),
          subtitle: Text(date.format(h.finishedAt)),
          trailing: Text(_weight(h.totalVolumeKg, unit)),
        ),
    ]);
  }
}

class _RecordsTab extends StatelessWidget {
  const _RecordsTab(this.p, this.unit);
  final ProgressData p;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return ListView(padding: const EdgeInsets.all(AppSpacing.base), children: [
      if (p.records.isEmpty) Text(l.progressNoRecords),
      for (final r in p.records)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.emoji_events_outlined, color: AppColors.mint),
          title: Text(lang == 'fr' ? r.exerciseNameFr : r.exerciseNameEn),
          subtitle: Text(l.progressE1rm(_weight(r.bestE1rmKg, unit))),
          trailing: Text(l.progressRecord(_weight(r.bestWeightKg, unit), r.bestReps)),
        ),
    ]);
  }
}

class _VolumeTab extends StatelessWidget {
  const _VolumeTab(this.p, this.unit);
  final ProgressData p;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final text = Theme.of(context).textTheme;
    final latest = p.weeklySets.isEmpty ? null : p.weeklySets.last;
    return ListView(padding: const EdgeInsets.all(AppSpacing.base), children: [
      if (p.balance case final b?)
        Card(
          child:
              ListTile(title: Text(l.progressBalanceTitle), subtitle: Text(l.progressBalance(b.pushSets, b.pullSets))),
        )
      else
        const _ProCard(),
      const SizedBox(height: AppSpacing.base),
      if (latest == null)
        Text(l.progressNoHistory)
      else ...[
        Text(l.progressWeeklySets(DateFormat.MMMd(lang).format(latest.weekStart)), style: text.titleMedium),
        for (final m in (latest.setsByMuscle.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(muscleLabel(m.key, lang)),
            trailing: Text(l.progressSets(m.value)),
          ),
      ],
      if (p.e1rmTrend.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        Text(l.progressE1rmTrend, style: text.titleMedium),
        for (final e in p.e1rmTrend.entries)
          _TrendRow(
            label: switch (p.exerciseNames[e.key]) { final n? => lang == 'fr' ? n.$2 : n.$1, null => e.key },
            points: e.value,
            unit: unit,
          ),
      ],
    ]);
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.label, required this.points, required this.unit});
  final String label;
  final List<E1rmPoint> points;
  final String unit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(children: [
          Expanded(child: Text(label)),
          if (points.length > 1)
            SizedBox(
              width: 120,
              height: 32,
              child: LineChart(LineChartData(
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].e1rmKg)],
                    color: AppColors.glacier,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              )),
            ),
          const SizedBox(width: AppSpacing.sm),
          Text(_weight(points.last.e1rmKg, unit)),
        ]),
      );
}

class _BodyWeightTab extends ConsumerWidget {
  const _BodyWeightTab(this.p, this.unit);
  final ProgressData p;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode);
    return ListView(padding: const EdgeInsets.all(AppSpacing.base), children: [
      OutlinedButton.icon(
        onPressed: () => _log(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l.progressLogBodyWeight),
      ),
      const SizedBox(height: AppSpacing.base),
      if (p.bodyWeight.isEmpty) Text(l.progressNoBodyWeight),
      for (final b in p.bodyWeight.reversed)
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_weight(b.weightKg, unit)),
            subtitle: Text(date.format(b.day))),
    ]);
  }

  Future<void> _log(BuildContext context, WidgetRef ref) async {
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BodyWeightSheet(unit: unit),
    );
    final userId = ref.read(currentUserIdProvider);
    if (value == null || userId == null) return;
    await ref
        .read(progressRepositoryProvider)
        .logBodyWeight(userId, unitToKg(value, unit), day: ref.read(clockProvider)());
    ref.invalidate(progressDataProvider);
  }
}

class _BodyWeightSheet extends StatefulWidget {
  const _BodyWeightSheet({required this.unit});
  final String unit;

  @override
  State<_BodyWeightSheet> createState() => _BodyWeightSheetState();
}

class _BodyWeightSheetState extends State<_BodyWeightSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final value = parseWeight(_controller.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.progressLogBodyWeight, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.base),
        TextField(
          key: const Key('body-weight-input'),
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: widget.unit),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.base),
        ElevatedButton(
          onPressed: value != null && value > 0 ? () => Navigator.of(context).pop(value) : null,
          child: Text(l.progressSave),
        ),
      ]),
    );
  }
}
