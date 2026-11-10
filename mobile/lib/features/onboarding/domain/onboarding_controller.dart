import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/api/supabase_client.dart';

part 'onboarding_controller.g.dart';

class OnboardingState {
  const OnboardingState({
    this.goal,
    this.level,
    this.daysPerWeek = 4,
    this.sessionLengthMin = 60,
    this.equipment = const [],
    this.limitations = '',
    this.isLoading = false,
    this.error,
  });

  final String? goal;
  final String? level;
  final int daysPerWeek;
  final int sessionLengthMin;
  final List<String> equipment;
  final String limitations;
  final bool isLoading;
  final String? error;

  /// Whether the user can proceed from the given step index.
  bool canProceed(int step) {
    return switch (step) {
      0 => goal != null,
      1 => level != null,
      2 => true, // Slider always has a value
      3 => true,
      4 => equipment.isNotEmpty,
      5 => true, // Limitations are optional
      _ => false,
    };
  }

  OnboardingState copyWith({
    String? goal,
    String? level,
    int? daysPerWeek,
    int? sessionLengthMin,
    List<String>? equipment,
    String? limitations,
    bool? isLoading,
    String? error,
  }) =>
      OnboardingState(
        goal: goal ?? this.goal,
        level: level ?? this.level,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        sessionLengthMin: sessionLengthMin ?? this.sessionLengthMin,
        equipment: equipment ?? this.equipment,
        limitations: limitations ?? this.limitations,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingState build() => const OnboardingState();

  void setGoal(String goal) => state = state.copyWith(goal: goal);
  void setLevel(String level) => state = state.copyWith(level: level);
  void setDaysPerWeek(int days) => state = state.copyWith(daysPerWeek: days);
  void setSessionLength(int minutes) =>
      state = state.copyWith(sessionLengthMin: minutes);

  void toggleEquipment(String item) {
    final current = List<String>.from(state.equipment);
    if (current.contains(item)) {
      current.remove(item);
    } else {
      current.add(item);
    }
    state = state.copyWith(equipment: current);
  }

  void setLimitations(String text) =>
      state = state.copyWith(limitations: text);

  /// Calls the generate-plan Edge Function.
  /// Navigation is handled by the caller (PlanGenerationScreen watches state.error).
  Future<void> submit() async {
    state = state.copyWith(isLoading: true);
    try {
      final dio = ref.read(dioClientProvider);
      await dio.post(
        '/functions/v1/generate-plan',
        data: {
          'goal': state.goal,
          'level': state.level,
          'days_per_week': state.daysPerWeek,
          'session_length_min': state.sessionLengthMin,
          'equipment': state.equipment,
          'limitations': state.limitations.isEmpty ? null : state.limitations,
        },
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
