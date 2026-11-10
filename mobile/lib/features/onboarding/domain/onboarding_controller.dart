import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import 'onboarding_gate.dart';

part 'onboarding_controller.g.dart';

/// Limitation tags (data-model users.limitations vocabulary).
const kLimitationTags = ['knee', 'lower_back', 'shoulder', 'wrist', 'elbow', 'hip', 'ankle', 'neck'];

/// Lifts asked in the optional strength check (users.strength_estimates).
const kStrengthLifts = ['squat', 'bench_press', 'deadlift'];

/// Result of `generate-plan` that the next screens need (contracts/backend-api.md §1).
class GeneratedPlanInfo {
  const GeneratedPlanInfo({required this.planId, required this.source, required this.fallbackNotice, required this.notices});
  final String planId;
  final String source;
  final bool fallbackNotice;
  final List<String> notices;
}

/// Backend calls made by onboarding; injectable for tests.
abstract class OnboardingApi {
  /// Upserts the `users` row for the signed-in user.
  Future<void> saveProfile(Map<String, dynamic> profile);
  Future<GeneratedPlanInfo> generatePlan();
  Future<String> deviceTimezone();
}

class SupabaseOnboardingApi implements OnboardingApi {
  SupabaseOnboardingApi(this._ref);
  final Ref _ref;

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    await client.from('users').upsert({'id': userId, ...profile});
  }

  @override
  Future<GeneratedPlanInfo> generatePlan() async {
    final response = await _ref.read(dioClientProvider).post<Map<String, dynamic>>(
          '/functions/v1/generate-plan',
          data: const <String, dynamic>{},
        );
    final plan = response.data!['plan'] as Map<String, dynamic>;
    return GeneratedPlanInfo(
      planId: plan['id'] as String,
      source: plan['source'] as String,
      fallbackNotice: plan['fallback_notice'] as bool? ?? false,
      notices: (plan['notices'] as List? ?? const []).cast<String>(),
    );
  }

  @override
  Future<String> deviceTimezone() => FlutterTimezone.getLocalTimezone();
}

@riverpod
OnboardingApi onboardingApi(Ref ref) => SupabaseOnboardingApi(ref);

class OnboardingState {
  const OnboardingState({
    this.disclaimerAccepted = false,
    this.consentAt,
    this.language,
    this.goal,
    this.level,
    this.daysPerWeek = 3,
    this.sessionLengthMin = 45,
    this.equipment = const [],
    this.limitations = const [],
    this.limitationsNote = '',
    this.strength = const {},
    this.isLoading = false,
    this.error,
    this.result,
  });

  final bool disclaimerAccepted;
  final DateTime? consentAt;

  /// 'en' | 'fr'; null until chosen (the quiz pre-selects the device locale).
  final String? language;
  final String? goal;
  final String? level;
  final int daysPerWeek;
  final int sessionLengthMin;
  final List<String> equipment;
  final List<String> limitations;
  final String limitationsNote;

  /// lift → (weight_kg, reps); a lift is absent when the user answered "I don't know".
  final Map<String, ({double weightKg, int reps})> strength;
  final bool isLoading;
  final String? error;
  final GeneratedPlanInfo? result;

  bool get consentGiven => consentAt != null;

  /// Steps: 0 language, 1 goal, 2 level, 3 days, 4 length, 5 equipment, 6 limitations, 7 strength.
  static const stepCount = 8;

  bool canProceed(int step) => switch (step) {
        0 => language != null,
        1 => goal != null,
        2 => level != null,
        5 => equipment.isNotEmpty,
        _ => step >= 0 && step < stepCount,
      };

  OnboardingState copyWith({
    bool? disclaimerAccepted,
    DateTime? consentAt,
    String? language,
    String? goal,
    String? level,
    int? daysPerWeek,
    int? sessionLengthMin,
    List<String>? equipment,
    List<String>? limitations,
    String? limitationsNote,
    Map<String, ({double weightKg, int reps})>? strength,
    bool? isLoading,
    String? error,
    GeneratedPlanInfo? result,
  }) =>
      OnboardingState(
        disclaimerAccepted: disclaimerAccepted ?? this.disclaimerAccepted,
        consentAt: consentAt ?? this.consentAt,
        language: language ?? this.language,
        goal: goal ?? this.goal,
        level: level ?? this.level,
        daysPerWeek: daysPerWeek ?? this.daysPerWeek,
        sessionLengthMin: sessionLengthMin ?? this.sessionLengthMin,
        equipment: equipment ?? this.equipment,
        limitations: limitations ?? this.limitations,
        limitationsNote: limitationsNote ?? this.limitationsNote,
        strength: strength ?? this.strength,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        result: result ?? this.result,
      );
}

@Riverpod(keepAlive: true)
class OnboardingController extends _$OnboardingController {
  @override
  OnboardingState build() => const OnboardingState();

  void acceptDisclaimer() => state = state.copyWith(disclaimerAccepted: true);
  void giveConsent([DateTime? at]) => state = state.copyWith(consentAt: at ?? DateTime.now().toUtc());
  void setLanguage(String code) => state = state.copyWith(language: code);
  void setGoal(String goal) => state = state.copyWith(goal: goal);
  void setLevel(String level) => state = state.copyWith(level: level);
  void setDaysPerWeek(int days) => state = state.copyWith(daysPerWeek: days.clamp(1, 7));
  void setSessionLength(int minutes) => state = state.copyWith(sessionLengthMin: minutes.clamp(15, 120));
  void setLimitationsNote(String text) => state = state.copyWith(limitationsNote: text);

  void toggleEquipment(String item) => state = state.copyWith(equipment: _toggle(state.equipment, item));

  void toggleLimitation(String tag) {
    assert(kLimitationTags.contains(tag));
    state = state.copyWith(limitations: _toggle(state.limitations, tag));
  }

  /// Sets a strength-check answer; `null` means "I don't know" for that lift.
  void setStrength(String lift, ({double weightKg, int reps})? value) {
    final next = Map.of(state.strength);
    if (value == null || value.weightKg <= 0 || value.reps <= 0) {
      next.remove(lift);
    } else {
      next[lift] = value;
    }
    state = state.copyWith(strength: next);
  }

  /// The `users` row for this profile (snake_case columns; weights already in kg).
  Map<String, dynamic> profileRow({required String timezone}) => {
        'goal': state.goal,
        'level': state.level,
        'days_per_week': state.daysPerWeek,
        'session_length_min': state.sessionLengthMin,
        'equipment': state.equipment,
        'limitations': state.limitations,
        'limitations_note': state.limitationsNote.trim().isEmpty ? null : state.limitationsNote.trim(),
        'language': state.language ?? 'en',
        'timezone': timezone,
        'consent_at': state.consentAt?.toIso8601String(),
        'consent_version': kConsentVersion,
        'strength_estimates': state.strength.isEmpty
            ? null
            : {for (final e in state.strength.entries) e.key: {'weight_kg': e.value.weightKg, 'reps': e.value.reps}},
      };

  /// Saves the profile, then generates the plan. The server always returns a plan (FR-003b);
  /// errors here are network/auth failures, shown with a retry.
  Future<void> submit() async {
    if (!state.consentGiven) {
      state = state.copyWith(error: 'consent_required');
      return;
    }
    state = state.copyWith(isLoading: true);
    final api = ref.read(onboardingApiProvider);
    try {
      final timezone = await api.deviceTimezone();
      await api.saveProfile(profileRow(timezone: timezone));
      final result = await api.generatePlan();
      state = state.copyWith(isLoading: false, result: result);
    } on Exception catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  static List<String> _toggle(List<String> list, String item) =>
      list.contains(item) ? (List.of(list)..remove(item)) : [...list, item];
}
