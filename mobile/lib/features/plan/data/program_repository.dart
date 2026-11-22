// Pro plan library (FR-047, 2026-11-21): ready-made programs such as a bro split or push/pull/legs.
// The catalog is the `plan_templates` rows that carry a `catalog` block; starting one calls
// `generate-plan` with `program_slug`, which adapts it to the user and replaces the active plan.
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/di/providers.dart';
import '../../../shared/models/equipment.dart';
import '../../../shared/services/api/supabase_client.dart';
import '../domain/plan_provider.dart';

/// One day of a program's week.
class ProgramDay {
  const ProgramDay({required this.dayOfWeek, required this.nameEn, required this.nameFr, required this.exerciseCount});

  /// 1 = Monday … 7 = Sunday.
  final int dayOfWeek;
  final String nameEn;
  final String nameFr;
  final int exerciseCount;

  String name(String languageCode) => languageCode == 'fr' ? nameFr : nameEn;
}

/// A program in the plan library.
class Program {
  const Program({
    required this.slug,
    required this.order,
    required this.nameEn,
    required this.nameFr,
    required this.summaryEn,
    required this.summaryFr,
    required this.rationaleEn,
    required this.rationaleFr,
    required this.level,
    required this.goal,
    required this.image,
    required this.weeksTotal,
    required this.equipmentRequired,
    required this.days,
  });

  /// Reads a `plan_templates.body`; null when the template is not in the library (no `catalog`).
  static Program? fromBody(Map<String, dynamic> body) {
    final catalog = body['catalog'];
    if (catalog is! Map<String, dynamic>) return null;
    final sessions = (body['sessions'] as List).cast<Map<String, dynamic>>();
    return Program(
      slug: body['slug'] as String,
      order: (catalog['order'] as num).toInt(),
      nameEn: body['name_en'] as String,
      nameFr: body['name_fr'] as String,
      summaryEn: catalog['summary_en'] as String,
      summaryFr: catalog['summary_fr'] as String,
      rationaleEn: body['rationale_en'] as String? ?? '',
      rationaleFr: body['rationale_fr'] as String? ?? '',
      level: body['level'] as String,
      goal: catalog['goal'] as String,
      image: catalog['image'] as String,
      weeksTotal: (body['weeks_total'] as num).toInt(),
      equipmentRequired: (body['equipment_required'] as List).cast<String>(),
      days: [
        for (final s in sessions)
          ProgramDay(
            dayOfWeek: (s['day_of_week'] as num).toInt(),
            nameEn: s['name_en'] as String,
            nameFr: s['name_fr'] as String,
            exerciseCount: (s['exercises'] as List).length,
          ),
      ]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek)),
    );
  }

  final String slug;
  final int order;
  final String nameEn;
  final String nameFr;
  final String summaryEn;
  final String summaryFr;
  final String rationaleEn;
  final String rationaleFr;
  final String level;

  /// muscle, strength, muscle_strength, lower_body or general.
  final String goal;

  /// Exercise slug whose photo stands for the program.
  final String image;
  final int weeksTotal;
  final List<String> equipmentRequired;
  final List<ProgramDay> days;

  int get daysPerWeek => days.length;
  String name(String languageCode) => languageCode == 'fr' ? nameFr : nameEn;
  String summary(String languageCode) => languageCode == 'fr' ? summaryFr : summaryEn;
  String rationale(String languageCode) => languageCode == 'fr' ? rationaleFr : rationaleEn;

  /// Equipment the program uses that the user does not have. The server swaps those exercises for
  /// ones the user can do (FR-047), so this is shown as information, not as a block.
  List<String> missingEquipment(List<String> userEquipment) {
    final have = withBodyweight(userEquipment).toSet();
    return equipmentRequired.where((e) => !have.contains(e)).toList();
  }
}

/// The server could not fit the program to the user's equipment and limitations (HTTP 422).
class ProgramNotSuitable implements Exception {
  const ProgramNotSuitable(this.details);
  final List<String> details;
}

/// The plan library is Pro only (HTTP 402).
class ProgramNeedsPro implements Exception {
  const ProgramNeedsPro();
}

abstract class ProgramApi {
  Future<List<Program>> fetchPrograms();

  /// Replaces the active plan with [slug], adapted to the user, then caches it on the device.
  Future<void> startProgram(String slug);
}

class SupabaseProgramApi implements ProgramApi {
  SupabaseProgramApi(this._ref);
  final Ref _ref;

  @override
  Future<List<Program>> fetchPrograms() async {
    final rows = await Supabase.instance.client.from('plan_templates').select('body');
    final programs = [
      for (final row in rows)
        if (Program.fromBody(row['body'] as Map<String, dynamic>) case final p?) p,
    ]..sort((a, b) => a.order.compareTo(b.order));
    return programs;
  }

  @override
  Future<void> startProgram(String slug) async {
    final TektoDioClient dio = _ref.read(dioClientProvider);
    try {
      await dio.post<Map<String, dynamic>>('/functions/v1/generate-plan',
          data: {'force_regenerate': true, 'program_slug': slug});
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 402) throw const ProgramNeedsPro();
      if (status == 422) {
        final data = e.response?.data;
        final body = data is String ? jsonDecode(data) : data;
        throw ProgramNotSuitable(((body as Map?)?['details'] as List?)?.cast<String>() ?? const []);
      }
      rethrow;
    }
    final userId = _ref.read(currentUserIdProvider);
    if (userId != null) await _ref.read(planRepositoryProvider).refreshActivePlan(userId);
  }
}

final programApiProvider = Provider<ProgramApi>((ref) => SupabaseProgramApi(ref));

final programsProvider = FutureProvider<List<Program>>((ref) => ref.watch(programApiProvider).fetchPrograms());

/// The signed-in user's equipment from the device copy of the profile.
final userEquipmentProvider = FutureProvider<List<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final db = ref.watch(appDatabaseProvider);
  final user = await (db.select(db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
  final raw = user?.equipment;
  return raw == null ? const [] : (jsonDecode(raw) as List).cast<String>();
});
