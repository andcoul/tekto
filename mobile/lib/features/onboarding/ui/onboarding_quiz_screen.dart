import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/onboarding_controller.dart';

/// Onboarding quiz (FR-001, T039). Step order: language, goal, level, days, session length,
/// equipment, limitations, optional strength check.
///
/// TODO(T094): step labels below use an inline EN/FR helper; move them to the ARB files.
class OnboardingQuizScreen extends ConsumerStatefulWidget {
  const OnboardingQuizScreen({super.key});

  @override
  ConsumerState<OnboardingQuizScreen> createState() => _OnboardingQuizScreenState();
}

class _OnboardingQuizScreenState extends ConsumerState<OnboardingQuizScreen> {
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // Pre-select the device language (en/fr) the first time the quiz opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(onboardingControllerProvider).language != null) return;
      final device = Localizations.localeOf(context).languageCode;
      _setLanguage(device == 'fr' ? 'fr' : 'en');
    });
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
          title: _t(context, 'What is your main goal?', 'Quel est votre objectif principal ?'),
          options: {
            'muscle': _t(context, 'Build muscle', 'Prendre du muscle'),
            'strength': _t(context, 'Get stronger', 'Gagner en force'),
            'fat_loss': _t(context, 'Lose fat', 'Perdre du gras'),
            'general_fitness': _t(context, 'General fitness', 'Forme générale'),
          },
          selected: state.goal,
          onSelect: ctrl.setGoal,
        ),
      2 => _ChoiceStep(
          title: _t(context, 'Your training level', 'Votre niveau'),
          options: {
            'beginner': _t(context, 'Beginner', 'Débutant'),
            'intermediate': _t(context, 'Intermediate', 'Intermédiaire'),
            'advanced': _t(context, 'Advanced', 'Avancé'),
          },
          selected: state.level,
          onSelect: ctrl.setLevel,
        ),
      3 => _SliderStep(
          title: _t(context, 'Days per week', 'Jours par semaine'),
          value: state.daysPerWeek,
          min: 1,
          max: 7,
          label: '${state.daysPerWeek}',
          onChanged: ctrl.setDaysPerWeek,
        ),
      4 => _SliderStep(
          title: _t(context, 'Session length', 'Durée des séances'),
          value: state.sessionLengthMin,
          min: 15,
          max: 120,
          divisions: 21,
          label: '${state.sessionLengthMin} min',
          onChanged: ctrl.setSessionLength,
        ),
      5 => _MultiStep(
          title: _t(context, 'Your equipment', 'Votre équipement'),
          options: {
            'barbell': _t(context, 'Barbell', 'Barre'),
            'dumbbell': _t(context, 'Dumbbells', 'Haltères'),
            'cable': _t(context, 'Cable / machines', 'Poulie / machines'),
            'bodyweight': _t(context, 'Bodyweight', 'Poids du corps'),
            'bands': _t(context, 'Resistance bands', 'Élastiques'),
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
        leading: _step > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _step--))
            : null,
        title: LinearProgressIndicator(
          value: (_step + 1) / OnboardingState.stepCount,
          backgroundColor: AppColors.charcoalElevated,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
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
                onPressed: state.canProceed(_step)
                    ? () {
                        if (isLast) {
                          ctrl.submit();
                          context.go('/onboarding/generating');
                        } else {
                          setState(() => _step++);
                        }
                      }
                    : null,
                child: Text(isLast ? _t(context, 'Build my plan', 'Créer mon programme') : _t(context, 'Next', 'Suivant')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _t(BuildContext context, String en, String fr) => Localizations.localeOf(context).languageCode == 'fr' ? fr : en;

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
  const _MultiStep({required this.title, required this.options, required this.selected, required this.onToggle});
  final String title;
  final Map<String, String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
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

  static const _labels = {
    'knee': ('Knee', 'Genou'),
    'lower_back': ('Lower back', 'Bas du dos'),
    'shoulder': ('Shoulder', 'Épaule'),
    'wrist': ('Wrist', 'Poignet'),
    'elbow': ('Elbow', 'Coude'),
    'hip': ('Hip', 'Hanche'),
    'ankle': ('Ankle', 'Cheville'),
    'neck': ('Neck', 'Cou'),
  };

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Text(_t(context, 'Any injuries or limitations?', 'Des blessures ou limitations ?'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(_t(context, 'Optional. We will avoid exercises that stress these areas.',
              'Facultatif. Nous éviterons les exercices qui sollicitent ces zones.')),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final tag in kLimitationTags)
                FilterChip(
                  label: Text(_t(context, _labels[tag]!.$1, _labels[tag]!.$2)),
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
            decoration: InputDecoration(labelText: _t(context, 'Anything else? (optional)', 'Autre chose ? (facultatif)')),
          ),
        ],
      );
}

/// Optional strength check: a recent working weight and reps per lift, or "I don't know".
class _StrengthStep extends StatelessWidget {
  const _StrengthStep({required this.values, required this.onChanged});
  final Map<String, ({double weightKg, int reps})> values;
  final void Function(String lift, ({double weightKg, int reps})? value) onChanged;

  static const _labels = {'squat': ('Squat', 'Squat'), 'bench_press': ('Bench press', 'Développé couché'), 'deadlift': ('Deadlift', 'Soulevé de terre')};

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Text(_t(context, 'Strength check (optional)', 'Test de force (facultatif)'), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(_t(context, 'A recent weight (kg) you lifted and for how many reps. Leave empty if you don\'t know — we start conservatively.',
              'Un poids récent (kg) et le nombre de répétitions. Laissez vide si vous ne savez pas — nous commencerons prudemment.')),
          const SizedBox(height: AppSpacing.lg),
          for (final lift in kStrengthLifts) _LiftRow(
            label: _t(context, _labels[lift]!.$1, _labels[lift]!.$2),
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
              decoration: InputDecoration(labelText: _t(context, 'reps', 'rép.')),
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
          color: selected ? AppColors.accent.withValues(alpha: 0.15) : AppColors.charcoalElevated,
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
                border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: 2),
              ),
              child: Row(children: [
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
                if (selected) const Icon(Icons.check_circle, color: AppColors.accent),
              ]),
            ),
          ),
        ),
      );
}
