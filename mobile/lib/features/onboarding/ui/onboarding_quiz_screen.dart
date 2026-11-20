import 'dart:convert';
import 'package:tekto/shared/models/equipment.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/features/settings/domain/settings_service.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/onboarding_controller.dart';

/// Onboarding quiz (FR-001, T039). Step order: language, goal, level, days, session length,
/// equipment, limitations, optional strength check.
///
/// TODO(T094): step labels below use an inline EN/FR helper; move them to the ARB files.
class OnboardingQuizScreen extends ConsumerStatefulWidget {
  const OnboardingQuizScreen({super.key, this.editProfile = false});

  /// Settings → "Edit my training profile" (FR-046, T131): starts prefilled from the saved
  /// profile, skips the language step (it has its own setting), saves instead of building a
  /// plan, then offers "Regenerate my plan". The active plan is untouched until confirmed.
  final bool editProfile;

  @override
  ConsumerState<OnboardingQuizScreen> createState() => _OnboardingQuizScreenState();
}

class _OnboardingQuizScreenState extends ConsumerState<OnboardingQuizScreen> {
  late int _step = _firstStep;
  bool _saving = false;

  int get _firstStep => widget.editProfile ? 1 : 0;

  @override
  void initState() {
    super.initState();
    if (widget.editProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
      return;
    }
    // Pre-select the device language (en/fr) the first time the quiz opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(onboardingControllerProvider).language != null) return;
      final device = Localizations.localeOf(context).languageCode;
      _setLanguage(device == 'fr' ? 'fr' : 'en');
    });
  }

  Future<void> _prefill() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final db = ref.read(appDatabaseProvider);
    final user = await (db.select(db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
    if (user == null || !mounted) return;
    List<String> list(String? json) => json == null ? const [] : (jsonDecode(json) as List).cast<String>();
    final strength = <String, ({double weightKg, int reps})>{};
    if (user.strengthEstimates case final raw?) {
      for (final MapEntry(:key, :value) in (jsonDecode(raw) as Map<String, dynamic>).entries) {
        final m = value as Map<String, dynamic>;
        strength[key] = (weightKg: (m['weight_kg'] as num).toDouble(), reps: (m['reps'] as num).toInt());
      }
    }
    ref.read(onboardingControllerProvider.notifier).prefill(
          goal: user.goal,
          level: user.level,
          daysPerWeek: user.daysPerWeek,
          sessionLengthMin: user.sessionLengthMin,
          equipment: list(user.equipment),
          limitations: list(user.limitations),
          limitationsNote: user.limitationsNote,
          strength: strength,
        );
  }

  /// Edit mode: save the answers, then offer to regenerate the plan (never automatically).
  Future<void> _saveEdits() async {
    final settings = ref.read(settingsServiceProvider);
    if (settings == null) return;
    final l = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      await settings.saveProfile(ref.read(onboardingControllerProvider.notifier).editableProfileRow());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    final regenerate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsRegeneratePlan),
        content: Text(l.profileEditRegenerateBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.profileEditNotNow)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.settingsRegenerateConfirm)),
        ],
      ),
    );
    if (regenerate == true) {
      try {
        await settings.regeneratePlan();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.settingsRegenerateDone)));
      } on Object {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.settingsRegenerateFailed)));
      }
    }
    if (mounted) context.canPop() ? context.pop() : context.go('/settings');
  }

  void _setLanguage(String code) {
    ref.read(onboardingControllerProvider.notifier).setLanguage(code);
    ref.read(appLocaleProvider.notifier).set(code);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final ctrl = ref.read(onboardingControllerProvider.notifier);
    final isLast = _step == OnboardingState.stepCount - 1;

    final step = switch (_step) {
      0 => _ChoiceStep(
          title: AppLocalizations.of(context).onboardingLanguageTitle,
          options: const {'en': 'English', 'fr': 'Français'},
          selected: state.language,
          onSelect: _setLanguage,
        ),
      1 => _ChoiceStep(
          title: AppLocalizations.of(context).quizGoalTitle,
          options: {
            'muscle': AppLocalizations.of(context).quizGoalMuscle,
            'strength': AppLocalizations.of(context).quizGoalStrength,
            'fat_loss': AppLocalizations.of(context).quizGoalFatLoss,
            'general_fitness': AppLocalizations.of(context).quizGoalGeneral,
          },
          selected: state.goal,
          onSelect: ctrl.setGoal,
        ),
      2 => _ChoiceStep(
          title: AppLocalizations.of(context).quizLevelTitle,
          options: {
            'beginner': AppLocalizations.of(context).quizLevelBeginner,
            'intermediate': AppLocalizations.of(context).quizLevelIntermediate,
            'advanced': AppLocalizations.of(context).quizLevelAdvanced,
          },
          selected: state.level,
          onSelect: ctrl.setLevel,
        ),
      3 => _SliderStep(
          title: AppLocalizations.of(context).quizDaysTitle,
          value: state.daysPerWeek,
          min: 1,
          max: 7,
          label: '${state.daysPerWeek}',
          onChanged: ctrl.setDaysPerWeek,
        ),
      4 => _SliderStep(
          title: AppLocalizations.of(context).quizSessionTitle,
          value: state.sessionLengthMin,
          min: 15,
          max: 120,
          divisions: 21,
          label: '${state.sessionLengthMin} min',
          onChanged: ctrl.setSessionLength,
        ),
      5 => _MultiStep(
          title: AppLocalizations.of(context).quizEquipmentTitle,
          // Bodyweight is always included, so it is not a choice (FR-001, clarified 2026-11-20).
          lead: _OptionCard(
            label: AppLocalizations.of(context).quizEquipmentGym,
            selected: kEquipmentChoices.every(state.equipment.contains),
            onTap: ctrl.toggleGym,
          ),
          options: {
            'barbell': AppLocalizations.of(context).quizEquipmentBarbell,
            'dumbbell': AppLocalizations.of(context).quizEquipmentDumbbell,
            'cable': AppLocalizations.of(context).quizEquipmentCable,
            'machine': AppLocalizations.of(context).quizEquipmentMachine,
            'bands': AppLocalizations.of(context).quizEquipmentBands,
            'pull_up_bar': AppLocalizations.of(context).quizEquipmentPullUpBar,
            'dip_station': AppLocalizations.of(context).quizEquipmentDipStation,
            'bench': AppLocalizations.of(context).quizEquipmentBench,
          },
          selected: state.equipment,
          onToggle: ctrl.toggleEquipment,
        ),
      6 => _LimitationsStep(
          selected: state.limitations,
          note: state.limitationsNote,
          onToggle: ctrl.toggleLimitation,
          onNote: ctrl.setLimitationsNote,
        ),
      _ => _StrengthStep(values: state.strength, onChanged: ctrl.setStrength),
    };

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _step > _firstStep
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => setState(() => _step--),
              )
            : (widget.editProfile ? const CloseButton() : null),
        title: LinearProgressIndicator(
          value: (_step + 1 - _firstStep) / (OnboardingState.stepCount - _firstStep),
          backgroundColor: AppColors.deep,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.glacier),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: step),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: state.canProceed(_step) && !_saving
                    ? () {
                        if (isLast && widget.editProfile) {
                          _saveEdits();
                        } else if (isLast) {
                          ctrl.submit();
                          context.go('/onboarding/generating');
                        } else {
                          setState(() => _step++);
                        }
                      }
                    : null,
                child: Text(isLast
                    ? (widget.editProfile
                        ? AppLocalizations.of(context).profileEditSave
                        : AppLocalizations.of(context).quizBuildPlan)
                    : AppLocalizations.of(context).quizNext),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceStep extends StatelessWidget {
  const _ChoiceStep({required this.title, required this.options, required this.selected, required this.onSelect});
  final String title;
  final Map<String, String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          for (final MapEntry(:key, :value) in options.entries)
            _OptionCard(label: value, selected: selected == key, onTap: () => onSelect(key)),
        ],
      );
}

class _MultiStep extends StatelessWidget {
  const _MultiStep(
      {required this.title, required this.options, required this.selected, required this.onToggle, this.lead});
  final String title;
  final Widget? lead;
  final Map<String, String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          if (lead != null) lead!,
          for (final MapEntry(:key, :value) in options.entries)
            _OptionCard(label: value, selected: selected.contains(key), onTap: () => onToggle(key)),
        ],
      );
}

class _SliderStep extends StatelessWidget {
  const _SliderStep({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.divisions,
  });
  final String title;
  final int value;
  final int min;
  final int max;
  final int? divisions;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          Text(label, style: Theme.of(context).textTheme.displayMedium, textAlign: TextAlign.center),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions ?? (max - min),
            label: label,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      );
}

class _LimitationsStep extends StatelessWidget {
  const _LimitationsStep({required this.selected, required this.note, required this.onToggle, required this.onNote});
  final List<String> selected;
  final String note;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onNote;

  static final _labels = <String, String Function(AppLocalizations)>{
    'knee': (l) => l.limitationKnee,
    'lower_back': (l) => l.limitationLowerBack,
    'shoulder': (l) => l.limitationShoulder,
    'wrist': (l) => l.limitationWrist,
    'elbow': (l) => l.limitationElbow,
    'hip': (l) => l.limitationHip,
    'ankle': (l) => l.limitationAnkle,
    'neck': (l) => l.limitationNeck,
  };

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Text(AppLocalizations.of(context).quizLimitationsTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(AppLocalizations.of(context).quizLimitationsBody),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in kLimitationTags)
                FilterChip(
                  label: Text(_labels[tag]!(AppLocalizations.of(context))),
                  selected: selected.contains(tag),
                  onSelected: (_) => onToggle(tag),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            initialValue: note,
            onChanged: onNote,
            maxLines: 3,
            decoration: InputDecoration(labelText: AppLocalizations.of(context).quizLimitationsNote),
          ),
        ],
      );
}

/// Optional strength check: a recent working weight and reps per lift, or "I don't know".
class _StrengthStep extends StatelessWidget {
  const _StrengthStep({required this.values, required this.onChanged});
  final Map<String, ({double weightKg, int reps})> values;
  final void Function(String lift, ({double weightKg, int reps})? value) onChanged;

  static final _labels = <String, String Function(AppLocalizations)>{
    'squat': (l) => l.liftSquat,
    'bench_press': (l) => l.liftBenchPress,
    'deadlift': (l) => l.liftDeadlift,
  };

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Text(AppLocalizations.of(context).quizStrengthTitle, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(AppLocalizations.of(context).quizStrengthBody),
          const SizedBox(height: AppSpacing.lg),
          for (final lift in kStrengthLifts)
            _LiftRow(
              label: _labels[lift]!(AppLocalizations.of(context)),
              value: values[lift],
              onChanged: (v) => onChanged(lift, v),
            ),
        ],
      );
}

class _LiftRow extends StatefulWidget {
  const _LiftRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final ({double weightKg, int reps})? value;
  final ValueChanged<({double weightKg, int reps})?> onChanged;

  @override
  State<_LiftRow> createState() => _LiftRowState();
}

class _LiftRowState extends State<_LiftRow> {
  late final _weight = TextEditingController(text: widget.value?.weightKg.toString() ?? '');
  late final _reps = TextEditingController(text: widget.value?.reps.toString() ?? '');

  void _emit() {
    final w = double.tryParse(_weight.text.replaceAll(',', '.'));
    final r = int.tryParse(_reps.text);
    widget.onChanged(w != null && r != null ? (weightKg: w, reps: r) : null);
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.base),
        child: Row(children: [
          Expanded(flex: 3, child: Text(widget.label)),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'kg'),
              onChanged: (_) => _emit(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _reps,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: AppLocalizations.of(context).quizReps),
              onChanged: (_) => _emit(),
            ),
          ),
        ]),
      );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Material(
          color: selected ? AppColors.glacier.withValues(alpha: 0.15) : AppColors.deep,
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget + 8),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                border: Border.all(color: selected ? AppColors.glacier : Colors.transparent, width: 2),
              ),
              child: Row(children: [
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
                if (selected) const Icon(Icons.check_circle, color: AppColors.glacier),
              ]),
            ),
          ),
        ),
      );
}
