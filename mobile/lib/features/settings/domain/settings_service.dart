import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/features/plan/domain/plan_provider.dart';
import 'package:tekto/shared/services/api/supabase_client.dart';
import 'package:tekto/shared/services/local_db/database.dart';
import 'package:tekto/shared/services/sync/sync_queue.dart';

/// Privacy policy (FR-038), linked from onboarding consent, settings and the paywall.
const kPrivacyPolicyUrl = 'https://tekto.app/privacy';

/// A signed export download link (contracts/backend-api.md §7), valid for 1 hour.
class ExportLink {
  const ExportLink({required this.url, required this.expiresAt});
  final Uri url;
  final DateTime? expiresAt;
}

/// Server calls made from Settings.
abstract class SettingsApi {
  /// `generate-plan` with `force_regenerate: true`, then the new plan is cached.
  Future<void> regeneratePlan();
  Future<ExportLink> exportData();

  /// `DELETE /delete-account` with `{ "confirm": true }`.
  Future<void> deleteAccount();
  Future<void> signOut();
  Future<String> deviceTimezone();
}

class UserSettings {
  const UserSettings({required this.language, required this.unit, required this.healthSyncEnabled});
  final String language;
  final String unit;
  final bool healthSyncEnabled;
}

/// Settings logic (T091). Preferences are written to the device first and queued for the
/// server, so they work offline and every screen reading the local profile follows at once.
class SettingsService {
  SettingsService({
    required AppDatabase db,
    required SyncQueue queue,
    required SettingsApi api,
    required String userId,
    required void Function(String languageCode) applyLocale,
    required Future<void> Function() wipeLocalData,
  })  : _db = db,
        _queue = queue,
        _api = api,
        _userId = userId,
        _applyLocale = applyLocale,
        _wipeLocalData = wipeLocalData;

  final AppDatabase _db;
  final SyncQueue _queue;
  final SettingsApi _api;
  final String _userId;
  final void Function(String languageCode) _applyLocale;
  final Future<void> Function() _wipeLocalData;

  static const languages = {'en', 'fr'};
  static const units = {'kg', 'lb'};

  Stream<UserSettings?> watch() => (_db.select(_db.users)..where((u) => u.id.equals(_userId)))
      .watchSingleOrNull()
      .map((u) => u == null ? null : UserSettings(language: u.language, unit: u.unit, healthSyncEnabled: u.healthSyncEnabled));

  /// FR-033: the app switches language immediately.
  Future<void> setLanguage(String languageCode) async {
    if (!languages.contains(languageCode)) throw ArgumentError.value(languageCode, 'languageCode');
    await _save(UsersCompanion(language: Value(languageCode)), {'language': languageCode});
    _applyLocale(languageCode);
  }

  /// FR-034: every weight display and input reads `users.unit` from the device.
  Future<void> setUnit(String unit) async {
    if (!units.contains(unit)) throw ArgumentError.value(unit, 'unit');
    await _save(UsersCompanion(unit: Value(unit)), {'unit': unit});
  }

  /// FR-012.
  Future<void> setHealthSync(bool enabled) =>
      _save(UsersCompanion(healthSyncEnabled: Value(enabled)), {'health_sync_enabled': enabled});

  /// Keeps `users.timezone` equal to the device zone, so the training week ends at the user's
  /// own Sunday 23:59 (FR-026). Returns true when it changed.
  Future<bool> syncTimezone() async {
    final zone = await _api.deviceTimezone();
    final user = await (_db.select(_db.users)..where((u) => u.id.equals(_userId))).getSingleOrNull();
    if (user == null || zone.isEmpty || user.timezone == zone) return false;
    await _save(UsersCompanion(timezone: Value(zone)), {'timezone': zone});
    return true;
  }

  /// Applies the stored language at launch (the choice survives restarts).
  Future<void> applySavedLanguage() async {
    final user = await (_db.select(_db.users)..where((u) => u.id.equals(_userId))).getSingleOrNull();
    if (user != null && languages.contains(user.language)) _applyLocale(user.language);
  }

  /// Saves edited onboarding answers (FR-046, T131) from [OnboardingController.editableProfileRow].
  /// The active plan is untouched; the caller offers "Regenerate my plan" afterwards.
  Future<void> saveProfile(Map<String, dynamic> fields) async {
    String? json(Object? v) => v == null ? null : jsonEncode(v);
    final local = UsersCompanion(
      goal: Value(fields['goal'] as String),
      level: Value(fields['level'] as String),
      daysPerWeek: Value(fields['days_per_week'] as int),
      sessionLengthMin: Value(fields['session_length_min'] as int),
      equipment: Value(jsonEncode(fields['equipment'])),
      limitations: Value(json(fields['limitations'])),
      limitationsNote: Value(fields['limitations_note'] as String?),
      strengthEstimates: Value(json(fields['strength_estimates'])),
    );
    await _save(local, fields);
  }

  Future<void> regeneratePlan() => _api.regeneratePlan();

  Future<ExportLink> exportData() => _api.exportData();

  /// FR-037: the server deletes the account first; only then is the device wiped, so a
  /// failed request never loses the user's local data.
  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    try {
      await _api.signOut();
    } on Object {
      // The account no longer exists; the local session is cleared by the wipe below.
    }
    await _wipeLocalData();
  }

  Future<void> _save(UsersCompanion local, Map<String, dynamic> server) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(_userId)))
        .write(local.copyWith(updatedAt: Value(DateTime.now())));
    await _queue.enqueue(operation: 'update', tableName: 'users', payload: {'id': _userId, ...server});
  }
}

class SupabaseSettingsApi implements SettingsApi {
  SupabaseSettingsApi(this._ref);
  final Ref _ref;

  TektoDioClient get _dio => _ref.read(dioClientProvider);

  @override
  Future<void> regeneratePlan() async {
    await _dio.post<Map<String, dynamic>>('/functions/v1/generate-plan', data: {'force_regenerate': true});
    final userId = _ref.read(currentUserIdProvider);
    if (userId != null) await _ref.read(planRepositoryProvider).refreshActivePlan(userId);
  }

  @override
  Future<ExportLink> exportData() async {
    final response = await _dio.post<Map<String, dynamic>>('/functions/v1/export-data', data: const {});
    final data = response.data ?? const {};
    return ExportLink(
      url: Uri.parse(data['download_url'] as String),
      expiresAt: DateTime.tryParse(data['expires_at'] as String? ?? ''),
    );
  }

  @override
  Future<void> deleteAccount() => _dio.delete<void>('/functions/v1/delete-account', data: {'confirm': true});

  @override
  Future<void> signOut() => Supabase.instance.client.auth.signOut();

  @override
  Future<String> deviceTimezone() => FlutterTimezone.getLocalTimezone();
}

/// Null when signed out.
final settingsServiceProvider = Provider<SettingsService?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return SettingsService(
    db: ref.watch(appDatabaseProvider),
    queue: ref.watch(syncQueueProvider),
    api: SupabaseSettingsApi(ref),
    userId: userId,
    applyLocale: (code) => ref.read(appLocaleProvider.notifier).set(code),
    wipeLocalData: () async {
      await ref.read(appDatabaseProvider).wipe();
      ref.invalidate(appDatabaseProvider); // a fresh, empty encrypted database
    },
  );
});
