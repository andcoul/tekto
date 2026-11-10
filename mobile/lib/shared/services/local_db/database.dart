import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ── Table definitions ──────────────────────────────────────────────────────

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get goal => text()();
  TextColumn get level => text()();
  IntColumn get daysPerWeek => integer()();
  IntColumn get sessionLengthMin => integer()();
  TextColumn get equipment => text()(); // JSON array
  TextColumn get limitations => text().nullable()(); // JSON array of limitation tags
  TextColumn get limitationsNote => text().nullable()();
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get unit => text().withDefault(const Constant('kg'))();
  TextColumn get timezone => text().withDefault(const Constant('UTC'))(); // IANA zone
  BoolColumn get healthSyncEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get consentAt => dateTime().nullable()();
  TextColumn get consentVersion => text().nullable()();
  TextColumn get strengthEstimates => text().nullable()(); // JSON {squat|bench_press|deadlift: {weight_kg, reps}}
  DateTimeColumn get onboardingCompletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Exercises extends Table {
  TextColumn get slug => text()();
  TextColumn get nameEn => text()();
  TextColumn get nameFr => text()();
  TextColumn get equipment => text()(); // JSON array
  TextColumn get musclePrimary => text()(); // JSON array
  TextColumn get muscleSecondary => text()(); // JSON array
  TextColumn get cuesEn => text()(); // JSON array
  TextColumn get cuesFr => text()(); // JSON array
  TextColumn get commonMistakesEn => text()(); // JSON array
  TextColumn get commonMistakesFr => text()(); // JSON array
  TextColumn get videoFrontUrl => text().nullable()();
  TextColumn get videoSideUrl => text().nullable()();
  IntColumn get videoDurationSec => integer().withDefault(const Constant(10))();
  TextColumn get captionsEnUrl => text().nullable()();
  TextColumn get captionsFrUrl => text().nullable()();
  TextColumn get contraindications => text().withDefault(const Constant('[]'))(); // JSON array of tags
  TextColumn get variationEasierSlug => text().nullable()();
  TextColumn get variationHarderSlug => text().nullable()();
  BoolColumn get formCheckSupported => boolean().withDefault(const Constant(false))();
  TextColumn get formCheckLiftKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {slug};
}

class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  IntColumn get weeksTotal => integer()();
  IntColumn get currentWeek => integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime().nullable()(); // Monday in the user's time zone
  IntColumn get lastAdaptedWeek => integer().withDefault(const Constant(0))();
  TextColumn get source => text().withDefault(const Constant('ai'))(); // ai | template | template_fallback
  TextColumn get templateSlug => text().nullable()();
  /// Deprecated: superseded by [source] / [templateSlug] (migration 005).
  TextColumn get generatedBy => text().withDefault(const Constant('ai'))();
  TextColumn get rationaleEn => text().nullable()();
  TextColumn get rationaleFr => text().nullable()();
  TextColumn get adaptationLog => text().withDefault(const Constant('[]'))(); // JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get planId => text()();
  IntColumn get weekNumber => integer()();
  IntColumn get dayOfWeek => integer()();
  TextColumn get nameEn => text()();
  TextColumn get nameFr => text()();
  TextColumn get muscleGroups => text()(); // JSON array
  IntColumn get estimatedMin => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PlanExercises extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get exerciseSlug => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get sets => integer()();
  IntColumn get repsMin => integer()();
  IntColumn get repsMax => integer()();
  RealColumn get rpeTarget => real().nullable()();
  IntColumn get restSec => integer().withDefault(const Constant(90))();
  RealColumn get suggestedWeightKg => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutLogs extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get sessionId => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get effortRating => integer().nullable()();
  RealColumn get totalVolumeKg => real().nullable()();
  BoolColumn get syncedToHealth => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class SetLogs extends Table {
  TextColumn get id => text()();
  TextColumn get workoutLogId => text()();
  TextColumn get planExerciseId => text()();
  IntColumn get setNumber => integer()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
  RealColumn get rpeActual => real().nullable()();
  BoolColumn get isPr => boolean().withDefault(const Constant(false))();
  DateTimeColumn get loggedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class PersonalRecords extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get exerciseSlug => text()();
  RealColumn get bestWeightKg => real()();
  IntColumn get bestReps => integer()();
  RealColumn get bestE1rm => real()();
  DateTimeColumn get achievedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class CoachConversations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get planId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class CoachMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get role => text()(); // 'user' | 'assistant' | 'system'
  TextColumn get content => text()();
  TextColumn get contextScreen => text().nullable()();
  TextColumn get contextExerciseSlug => text().nullable()();
  TextColumn get planChangeProposed => text().nullable()(); // JSON
  BoolColumn get planChangeApplied => boolean().withDefault(const Constant(false))();
  BoolColumn get satisfactionRating => boolean().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class CoachQuotaUsage extends Table {
  TextColumn get userId => text()();
  TextColumn get isoWeek => text()();
  IntColumn get questionsUsed => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {userId, isoWeek};
}

class FormCheckSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get exerciseSlug => text()();
  TextColumn get workoutLogId => text().nullable()();
  IntColumn get repCount => integer().withDefault(const Constant(0))();
  IntColumn get formScore => integer().nullable()();
  TextColumn get cuesShown => text().withDefault(const Constant('[]'))(); // JSON array
  TextColumn get flaggedReps => text().withDefault(const Constant('[]'))(); // JSON array of 1-based reps
  TextColumn get topTipEn => text().nullable()();
  TextColumn get topTipFr => text().nullable()();
  BoolColumn get wasFreeTry => boolean().withDefault(const Constant(false))();
  BoolColumn get userShared => boolean().withDefault(const Constant(false))(); // Principle II: false unless the user confirms a share
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Subscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get tier => text().withDefault(const Constant('free'))();
  BoolColumn get isTrial => boolean().withDefault(const Constant(false))();
  DateTimeColumn get trialEndsAt => dateTime().nullable()();
  DateTimeColumn get currentPeriodEndsAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get revenuecatCustomerId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Device-only (never synced): one row per exercise downloaded on this device (Pro only).
class ExerciseVideoDownloads extends Table {
  TextColumn get exerciseSlug => text()();
  TextColumn get localPath => text()();
  TextColumn get captionsLocalPaths => text().withDefault(const Constant('{}'))(); // JSON {"en": path, "fr": path}
  DateTimeColumn get downloadedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {exerciseSlug};
}

/// Local-only offline write queue (Principle I). Flushed in [id] order.
class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => text()(); // 'insert' | 'update' | 'delete'
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get payload => text()(); // JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))(); // max 3, then status = failed
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending' | 'failed'
}

// ── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Users,
  Exercises,
  Plans,
  Sessions,
  PlanExercises,
  WorkoutLogs,
  SetLogs,
  PersonalRecords,
  CoachConversations,
  CoachMessages,
  CoachQuotaUsage,
  FormCheckSessions,
  Subscriptions,
  ExerciseVideoDownloads,
  SyncQueueTable,
])
class AppDatabase extends _$AppDatabase {
  /// Production database: SQLCipher-encrypted file, key in the OS keystore (Constitution II).
  AppDatabase() : super(_openEncrypted());

  /// Tests: pass e.g. `NativeDatabase.memory()`.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Deletes the encrypted database file and its key (account deletion). The instance is
  /// unusable afterwards; recreate the provider.
  Future<void> wipe() async {
    await close();
    final file = await _databaseFile();
    if (await file.exists()) await file.delete();
    await _keyStorage.delete(key: _keyName);
  }
}

// ── Encrypted connection (SQLCipher) ───────────────────────────────────────

const _fileName = 'tekto_encrypted.sqlite';
const _legacyPlaintextFileName = 'tekto_local.sqlite'; // drift_flutter default before encryption
const _keyName = 'tekto_db_key_v1';
const _keyStorage = FlutterSecureStorage();

Future<File> _databaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$_fileName');
}

/// Returns the stored 256-bit key, generating and storing one on first launch.
Future<String> _databaseKey() async {
  final existing = await _keyStorage.read(key: _keyName);
  if (existing != null) return existing;
  final random = Random.secure();
  final key = List.generate(32, (_) => random.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  await _keyStorage.write(key: _keyName, value: key);
  return key;
}

QueryExecutor _openEncrypted() {
  return LazyDatabase(() async {
    final file = await _databaseFile();
    await _deleteLegacyPlaintextDatabase(file.parent);
    final key = await _databaseKey();
    return NativeDatabase.createInBackground(
      file,
      // SQLCipher is bundled by package:sqlite3's build hook (pubspec `hooks.user_defines`).
      setup: (rawDb) {
        final cipher = rawDb.select('PRAGMA cipher_version;');
        if (cipher.isEmpty) {
          throw StateError('SQLCipher is not available; refusing to open an unencrypted database.');
        }
        rawDb.execute("PRAGMA key = '$key';"); // key is hex only — no quoting issues
      },
    );
  });
}

/// Pre-encryption builds stored a plaintext file; remove it so no health data stays unencrypted.
Future<void> _deleteLegacyPlaintextDatabase(Directory documentsDir) async {
  final support = await getApplicationSupportDirectory();
  for (final dir in [documentsDir, support]) {
    final legacy = File('${dir.path}/$_legacyPlaintextFileName');
    if (await legacy.exists()) await legacy.delete();
  }
}
