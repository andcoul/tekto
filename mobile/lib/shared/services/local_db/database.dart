import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';

part 'database.g.dart';

// ── Table definitions ──────────────────────────────────────────────────────

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get goal => text()();
  TextColumn get level => text()();
  IntColumn get daysPerWeek => integer()();
  IntColumn get sessionLengthMin => integer()();
  TextColumn get equipment => text()(); // JSON array
  TextColumn get limitations => text().nullable()(); // JSON array
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get unit => text().withDefault(const Constant('kg'))();
  BoolColumn get healthSyncEnabled => boolean().withDefault(const Constant(false))();
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
  TextColumn get topTipEn => text().nullable()();
  TextColumn get topTipFr => text().nullable()();
  BoolColumn get userShared => boolean().withDefault(const Constant(false))();
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

class ExerciseVideoDownloads extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get exerciseSlug => text()();
  TextColumn get planId => text()();
  TextColumn get localPath => text().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();
  DateTimeColumn get downloadedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Offline sync queue — stores operations while device is offline.
class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  TextColumn get id => text()();
  TextColumn get operation => text()(); // 'INSERT' | 'UPDATE' | 'DELETE'
  TextColumn get tableName_ => text().named('table_name')();
  TextColumn get payload => text()(); // JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
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
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'tekto_local');
  }
}
