import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../shared/services/form_check/rep_counter.dart';
import '../../library/domain/exercise_provider.dart';
import '../../subscription/domain/entitlement_provider.dart';
import '../data/form_check_repository.dart';
import 'form_check_free_try_service.dart';

/// Whether the form check for one exercise can open, and for which lift.
class FormCheckGate {
  const FormCheckGate({required this.liftKey, required this.access});

  /// Exercise without form check, or not one of the launch lifts.
  const FormCheckGate.unsupported()
      : liftKey = null,
        access = FormCheckAccess.blocked;

  final String? liftKey;
  final FormCheckAccess access;

  bool get supported => liftKey != null;
}

/// Gate for `/form-check/<slug>`, from local data only (works offline, FR-029). Re-runs when
/// the entitlement changes, so buying Pro from the paywall unlocks the screen at once.
final formCheckGateProvider = FutureProvider.autoDispose.family<FormCheckGate, String>((ref, slug) async {
  final exercises = await ref.watch(exercisesProvider.future);
  final exercise = exercises.where((e) => e.slug == slug).firstOrNull;
  final liftKey = exercise?.formCheckLiftKey;
  if (exercise == null ||
      !exercise.formCheckSupported ||
      liftKey == null ||
      !RepCounter.launchLifts.contains(liftKey)) {
    return const FormCheckGate.unsupported();
  }
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return FormCheckGate(liftKey: liftKey, access: FormCheckAccess.blocked);
  final isPro = (await ref.watch(entitlementProvider.future)).isPro;
  final access = await ref.watch(formCheckFreeTryServiceProvider).check(userId: userId, liftKey: liftKey, isPro: isPro);
  return FormCheckGate(liftKey: liftKey, access: access);
});

/// Device cameras; widget tests override it so no platform channel is used.
final formCheckCamerasProvider = FutureProvider.autoDispose<List<CameraDescription>>((ref) => availableCameras());
