// Pro plan library (FR-047): pick a ready-made program, see its week, start it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/equipment_labels.dart';
import '../../subscription/domain/entitlement_provider.dart';
import '../data/program_repository.dart';
import '../domain/plan_provider.dart';

/// Filters shown above the list.
enum ProgramFilter { all, three, four, fivePlus, strength, home }

bool programMatches(Program p, ProgramFilter f) => switch (f) {
      ProgramFilter.all => true,
      ProgramFilter.three => p.daysPerWeek <= 3,
      ProgramFilter.four => p.daysPerWeek == 4,
      ProgramFilter.fivePlus => p.daysPerWeek >= 5,
      ProgramFilter.strength => p.goal == 'strength' || p.goal == 'muscle_strength',
      ProgramFilter.home => !p.equipmentRequired.contains('barbell') && !p.equipmentRequired.contains('machine'),
    };

String programLevelLabel(AppLocalizations l, String level) => switch (level) {
      'beginner' => l.programLevelBeginner,
      'advanced' => l.programLevelAdvanced,
      _ => l.programLevelIntermediate,
    };

class ProgramLibraryScreen extends ConsumerStatefulWidget {
  const ProgramLibraryScreen({super.key});

  @override
  ConsumerState<ProgramLibraryScreen> createState() => _ProgramLibraryScreenState();
}

class _ProgramLibraryScreenState extends ConsumerState<ProgramLibraryScreen> {
  ProgramFilter _filter = ProgramFilter.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final programs = ref.watch(programsProvider);
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;
    final current = ref.watch(activePlanProvider).value;
    final labels = {
      ProgramFilter.all: l.programFilterAll,
      ProgramFilter.three: l.programFilterThree,
      ProgramFilter.four: l.programFilterFour,
      ProgramFilter.fivePlus: l.programFilterFivePlus,
      ProgramFilter.strength: l.programFilterStrength,
      ProgramFilter.home: l.programFilterHome,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.programLibraryTitle), actions: [
        if (isPro) const Padding(padding: EdgeInsets.only(right: AppSpacing.base), child: Center(child: _ProBadge())),
      ]),
      body: programs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(l.programLoadError, textAlign: TextAlign.center),
          ),
        ),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.xl),
          children: [
            Text(l.programLibraryHeadline, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(l.programLibraryBody, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.base),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in ProgramFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(labels[f]!),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (current != null)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.glacier),
                ),
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome, color: AppColors.glacier),
                  title: Text(current.name),
                  subtitle: Text(l.programCurrentLabel),
                  trailing: const Icon(Icons.check, color: AppColors.glacier),
                ),
              ),
            if (!isPro)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lock_outline, color: AppColors.glacier),
                  title: Text(l.programProOnly),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/paywall?feature=general'),
                ),
              ),
            for (final p in list.where((p) => programMatches(p, _filter)))
              Card(
                key: ValueKey('program-${p.slug}'),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.fitness_center, color: AppColors.glacier),
                  ),
                  title: Text(p.name(lang), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${l.programDaysPerWeek(p.daysPerWeek)} · ${programLevelLabel(l, p.level)}\n${p.summary(lang)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/plan/programs/${p.slug}'),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.mist),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(l.programSafetyNote, style: Theme.of(context).textTheme.bodySmall)),
            ]),
          ],
        ),
      ),
    );
  }
}

class ProgramDetailScreen extends ConsumerStatefulWidget {
  const ProgramDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends ConsumerState<ProgramDetailScreen> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final program = ref.watch(programsProvider).value?.where((p) => p.slug == widget.slug).firstOrNull;
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;
    final missing = program?.missingEquipment(ref.watch(userEquipmentProvider).value ?? const []) ?? const [];

    if (program == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final dayNames = [l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat, l.daySun];
    final trainDays = program.days.map((d) => d.dayOfWeek).toSet();

    return Scaffold(
      appBar: AppBar(title: Text(program.name(lang))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.base, 0, AppSpacing.base, AppSpacing.xl),
        children: [
          Text(program.rationale(lang), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.base),
          Row(children: [
            _Stat(value: '${program.daysPerWeek}', label: l.programStatDays),
            const SizedBox(width: AppSpacing.sm),
            _Stat(value: programLevelLabel(l, program.level), label: l.programStatLevel),
            const SizedBox(width: AppSpacing.sm),
            _Stat(value: l.programWeeks(program.weeksTotal), label: l.programStatLength),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Text(l.programYourWeek, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final d in program.days)
            Card(
              child: ListTile(
                leading: SizedBox(width: 44, child: Center(child: Text(dayNames[d.dayOfWeek - 1]))),
                title: Text(d.name(lang), style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: Text(l.programExerciseCount(d.exerciseCount)),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 7; i++)
                Container(
                  width: 40,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: trainDays.contains(i) ? AppColors.glacier : null,
                    border: trainDays.contains(i) ? null : Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    dayNames[i - 1].characters.first,
                    style: TextStyle(color: trainDays.contains(i) ? AppColors.ink : AppColors.mist),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Text(
                missing.isEmpty
                    ? l.programFitNote
                    : l.programAdaptNote(missing.map((e) => equipmentLabel(l, e)).join(', ')),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            key: const ValueKey('program-start'),
            onPressed: _starting ? null : () => isPro ? _start(program) : context.push('/paywall?feature=general'),
            child: _starting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(isPro ? l.programStart : l.programUnlock),
          ),
        ],
      ),
    );
  }

  Future<void> _start(Program program) async {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.programConfirmTitle(program.name(lang))),
        content: Text(l.programConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancelButton)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.programStart)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _starting = true);
    String? message;
    try {
      await ref.read(programApiProvider).startProgram(program.slug);
    } on ProgramNotSuitable {
      message = l.programNotSuitable;
    } on ProgramNeedsPro {
      if (mounted) await context.push('/paywall?feature=general');
    } on Object {
      message = l.programStartFailed;
    }
    if (!mounted) return;
    setState(() => _starting = false);
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.programStarted)));
      context.go('/plan');
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
            child: Column(children: [
              Text(value, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: AppColors.glacier, borderRadius: BorderRadius.circular(6)),
        child: const Text('PRO',
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 1.2, color: AppColors.ink)),
      );
}
