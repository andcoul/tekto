import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';

// ---------------------------------------------------------------------------
// Adaptation state
// ---------------------------------------------------------------------------

class AdaptationSummary {
  const AdaptationSummary({
    required this.events,
    required this.week,
  });

  final List<AdaptationEvent> events;
  final int week;
}

class AdaptationEvent {
  const AdaptationEvent({
    required this.planExerciseId,
    required this.field,
    required this.oldValue,
    required this.newValue,
    required this.reasonEn,
    required this.reasonFr,
  });

  final String planExerciseId;
  final String field; // 'suggested_weight_kg' | 'reps_max'
  final double oldValue;
  final double newValue;
  final String reasonEn;
  final String reasonFr;
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class AdaptationNotifier extends AsyncNotifier<AdaptationSummary?> {
  @override
  Future<AdaptationSummary?> build() async => null;

  /// Triggers week adaptation for [planId] after [completedWeek] is done.
  Future<void> adapt({
    required String planId,
    required int completedWeek,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final client = ref.read(tektoApiClientProvider);
      final response = await client.post<Map<String, dynamic>>(
        '/functions/v1/adapt-plan',
        data: {
          'plan_id': planId,
          'completed_week': completedWeek,
        },
      );

      final data = response.data;
      if (data == null || data['adapted'] == false) return null;

      final rawEvents =
          (data['events'] as List<dynamic>? ?? []);

      return AdaptationSummary(
        week: completedWeek,
        events: rawEvents.map((e) {
          final map = e as Map<String, dynamic>;
          return AdaptationEvent(
            planExerciseId: map['planExerciseId'] as String,
            field: map['field'] as String,
            oldValue: (map['oldValue'] as num).toDouble(),
            newValue: (map['newValue'] as num).toDouble(),
            reasonEn: map['reasonEn'] as String? ?? '',
            reasonFr: map['reasonFr'] as String? ?? '',
          );
        }).toList(),
      );
    });
  }
}

final adaptationProvider =
    AsyncNotifierProvider<AdaptationNotifier, AdaptationSummary?>(
  AdaptationNotifier.new,
);
