import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/onboarding_controller.dart';

class OnboardingQuizScreen extends ConsumerStatefulWidget {
  const OnboardingQuizScreen({super.key});

  @override
  ConsumerState<OnboardingQuizScreen> createState() =>
      _OnboardingQuizScreenState();
}

class _OnboardingQuizScreenState extends ConsumerState<OnboardingQuizScreen> {
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);

    final steps = [
      _GoalStep(
        selected: state.goal,
        onSelect: (g) => ref.read(onboardingControllerProvider.notifier).setGoal(g),
      ),
      _LevelStep(
        selected: state.level,
        onSelect: (l) => ref.read(onboardingControllerProvider.notifier).setLevel(l),
      ),
      _DaysStep(
        value: state.daysPerWeek,
        onChanged: (d) =>
            ref.read(onboardingControllerProvider.notifier).setDaysPerWeek(d),
      ),
      _SessionLengthStep(
        value: state.sessionLengthMin,
        onChanged: (m) =>
            ref.read(onboardingControllerProvider.notifier).setSessionLength(m),
      ),
      _EquipmentStep(
        selected: state.equipment,
        onToggle: (e) =>
            ref.read(onboardingControllerProvider.notifier).toggleEquipment(e),
      ),
      _LimitationsStep(
        value: state.limitations,
        onChanged: (l) =>
            ref.read(onboardingControllerProvider.notifier).setLimitations(l),
      ),
    ];

    final isLast = _step == steps.length - 1;

    return Scaffold(
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step--),
              )
            : null,
        title: LinearProgressIndicator(
          value: (_step + 1) / steps.length,
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
              Expanded(child: steps[_step]),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: state.canProceed(_step)
                    ? () {
                        if (isLast) {
                          _submit();
                        } else {
                          setState(() => _step++);
                        }
                      }
                    : null,
                child: Text(isLast ? 'Generate My Plan' : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    context.go('/onboarding/generating');
    ref.read(onboardingControllerProvider.notifier).submit();
  }
}

// ── Step widgets ───────────────────────────────────────────────────────────

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _goals = [
    ('muscle', 'Build muscle', Icons.fitness_center),
    ('strength', 'Get stronger', Icons.trending_up),
    ('fat_loss', 'Lose fat', Icons.local_fire_department),
    ('general_fitness', 'General fitness', Icons.directions_run),
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What\'s your main goal?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          ..._goals.map(
            (g) => _OptionCard(
              label: g.$2,
              icon: g.$3,
              selected: selected == g.$1,
              onTap: () => onSelect(g.$1),
            ),
          ),
        ],
      );
}

class _LevelStep extends StatelessWidget {
  const _LevelStep({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _levels = [
    ('beginner', 'Beginner', 'Less than 1 year of consistent training'),
    ('intermediate', 'Intermediate', '1–3 years of consistent training'),
    ('advanced', 'Advanced', '3+ years, comfortable with compound lifts'),
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How experienced are you?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          ..._levels.map(
            (l) => _OptionCard(
              label: l.$2,
              subtitle: l.$3,
              selected: selected == l.$1,
              onTap: () => onSelect(l.$1),
            ),
          ),
        ],
      );
}

class _DaysStep extends StatelessWidget {
  const _DaysStep({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How many days per week can you train?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              '$value days/week',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          Slider(
            value: value.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            activeColor: AppColors.accent,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      );
}

class _SessionLengthStep extends StatelessWidget {
  const _SessionLengthStep({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How long is each session?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              '$value minutes',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          Slider(
            value: value.toDouble(),
            min: 15,
            max: 120,
            divisions: 21,
            activeColor: AppColors.accent,
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      );
}

class _EquipmentStep extends StatelessWidget {
  const _EquipmentStep({required this.selected, required this.onToggle});
  final List<String> selected;
  final ValueChanged<String> onToggle;

  static const _options = [
    ('barbell', 'Barbell', Icons.sports_gymnastics),
    ('dumbbell', 'Dumbbell', Icons.fitness_center),
    ('cable', 'Cable machine', Icons.cable),
    ('bodyweight', 'Bodyweight only', Icons.accessibility_new),
    ('bands', 'Resistance bands', Icons.change_history),
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What equipment do you have?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('Select all that apply',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _options
                .map(
                  (opt) => FilterChip(
                    label: Text(opt.$2),
                    avatar: Icon(opt.$3, size: 16),
                    selected: selected.contains(opt.$1),
                    onSelected: (_) => onToggle(opt.$1),
                  ),
                )
                .toList(),
          ),
        ],
      );
}

class _LimitationsStep extends StatefulWidget {
  const _LimitationsStep({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_LimitationsStep> createState() => _LimitationsStepState();
}

class _LimitationsStepState extends State<_LimitationsStep> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Any limitations we should know?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text('Optional', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _ctrl,
            onChanged: widget.onChanged,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'e.g. lower back injury, bad knees…',
            ),
          ),
        ],
      );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withOpacity(0.15) : AppColors.charcoalSurface,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius),
            border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: selected ? AppColors.accent : AppColors.onDarkSecondary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.accent),
            ],
          ),
        ),
      );
}
