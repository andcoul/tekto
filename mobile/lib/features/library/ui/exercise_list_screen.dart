import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/exercise_model.dart';
import '../domain/exercise_provider.dart';

class ExerciseListScreen extends ConsumerStatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  String? _selectedEquipment;
  String? _selectedMuscle;
  String _query = '';

  static const _muscleGroups = [
    'quadriceps', 'glutes', 'hamstrings', 'chest', 'shoulders',
    'lats', 'traps', 'biceps', 'triceps', 'core', 'erectors',
  ];

  static const _equipment = [
    'barbell', 'dumbbell', 'cable', 'bodyweight', 'bands',
  ];

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(
      filteredExercisesProvider(
        equipment: _selectedEquipment,
        muscle: _selectedMuscle,
        query: _query.isEmpty ? null : _query,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _query = ''),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _FilterChips(
            muscles: _muscleGroups,
            equipment: _equipment,
            selectedMuscle: _selectedMuscle,
            selectedEquipment: _selectedEquipment,
            onMuscleSelected: (m) => setState(() =>
                _selectedMuscle = _selectedMuscle == m ? null : m),
            onEquipmentSelected: (e) => setState(() =>
                _selectedEquipment = _selectedEquipment == e ? null : e),
          ),
          Expanded(
            child: exercisesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (exercises) => exercises.isEmpty
                  ? const Center(child: Text('No exercises found.'))
                  : ListView.builder(
                      itemCount: exercises.length,
                      itemBuilder: (context, index) =>
                          _ExerciseRow(exercise: exercises[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.muscles,
    required this.equipment,
    required this.selectedMuscle,
    required this.selectedEquipment,
    required this.onMuscleSelected,
    required this.onEquipmentSelected,
  });

  final List<String> muscles;
  final List<String> equipment;
  final String? selectedMuscle;
  final String? selectedEquipment;
  final ValueChanged<String> onMuscleSelected;
  final ValueChanged<String> onEquipmentSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...muscles.map(
            (m) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_capitalize(m)),
                selected: selectedMuscle == m,
                onSelected: (_) => onMuscleSelected(m),
              ),
            ),
          ),
          const VerticalDivider(width: 16),
          ...equipment.map(
            (e) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_capitalize(e)),
                selected: selectedEquipment == e,
                onSelected: (_) => onEquipmentSelected(e),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});
  final ExerciseModel exercise;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      leading: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.charcoalElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.fitness_center, color: AppColors.accent),
      ),
      title: Text(exercise.nameEn),
      subtitle: Text(
        exercise.musclePrimary.join(', '),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/library/${exercise.slug}'),
    );
  }
}
