import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/plan_model.dart';
import '../../../shared/services/local_db/database.dart';
import '../data/plan_repository.dart';

part 'plan_provider.g.dart';

@riverpod
PlanRepository planRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = Supabase.instance.client;
  return PlanRepository(db: db, supabase: supabase);
}

@riverpod
Stream<PlanModel?> activePlan(Ref ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
  return ref.watch(planRepositoryProvider).watchActivePlan(userId);
}
