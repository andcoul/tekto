import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/plan_model.dart';
import '../../../core/di/providers.dart';
import '../../library/domain/exercise_provider.dart';
import '../data/plan_repository.dart';

part 'plan_provider.g.dart';

@riverpod
PlanRepository planRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final supabase = Supabase.instance.client;
  return PlanRepository(db: db, supabase: supabase);
}

/// The active plan from the device cache, refreshed from the server when online.
/// The refresh also caches every exercise's text so today's workout works offline (Constitution I).
@riverpod
Stream<PlanModel?> activePlan(Ref ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
  final repo = ref.watch(planRepositoryProvider);
  unawaited(repo.refreshActivePlan(userId).catchError((Object _) {})); // offline: keep the local copy
  unawaited(ref.read(exerciseRepositoryProvider).getAll().catchError((Object _) => <Never>[]));
  return repo.watchActivePlan(userId);
}
