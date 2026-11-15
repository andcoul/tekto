import '../../../shared/services/local_db/daos/form_check_dao.dart';

/// Whether a form check may start, and how it is recorded.
enum FormCheckAccess {
  /// Pro or active trial: unlimited, not a free try.
  pro,

  /// Free user's one try for this lift (saved with `was_free_try = true`).
  freeTry,

  /// Free user who already used this lift's try: show the paywall.
  blocked;

  bool get allowed => this != blocked;
  bool get wasFreeTry => this == freeTry;
}

/// Free tier: one form check per launch lift (FR-029). Decided from the local mirror only,
/// so it works offline; the variant does not matter (goblet and back squat share `squat`).
class FormCheckFreeTryService {
  const FormCheckFreeTryService({required FormCheckDao dao}) : _dao = dao;

  final FormCheckDao _dao;

  Future<FormCheckAccess> check({required String userId, required String liftKey, required bool isPro}) async {
    if (isPro) return FormCheckAccess.pro;
    return await _dao.hasFreeTry(userId, liftKey) ? FormCheckAccess.blocked : FormCheckAccess.freeTry;
  }
}
