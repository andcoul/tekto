import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:tekto/core/di/providers.dart';
import 'package:tekto/shared/models/coach_model.dart';
import 'package:tekto/shared/services/local_db/daos/coach_dao.dart';
import 'package:tekto/shared/services/local_db/database.dart';

const _uuid = Uuid();

/// Manages individual coach messages within a conversation (local Drift cache).
class CoachMessageRepository {
  const CoachMessageRepository({required CoachDao dao, DateTime Function() clock = DateTime.now})
      : _dao = dao,
        _clock = clock;

  final CoachDao _dao;
  final DateTime Function() _clock;

  /// Stores a new message and returns it.
  Future<CoachMessageModel> addMessage({
    required String conversationId,
    required String role,
    required String content,
    String? screenContext,
    String? exerciseSlug,
    Map<String, dynamic>? planChangeProposed,
  }) async {
    final message = CoachMessageModel(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: role,
      content: content,
      contextScreen: screenContext,
      contextExerciseSlug: exerciseSlug,
      planChangeProposed: planChangeProposed,
      planChangeApplied: false,
      createdAt: _clock(),
    );
    await _dao.insertMessage(CoachMessagesCompanion.insert(
      id: message.id,
      conversationId: conversationId,
      role: role,
      content: content,
      contextScreen: Value(screenContext),
      contextExerciseSlug: Value(exerciseSlug),
      planChangeProposed: Value(planChangeProposed == null ? null : jsonEncode(planChangeProposed)),
      createdAt: Value(message.createdAt),
    ));
    return message;
  }

  /// Messages of a conversation, oldest first.
  Stream<List<CoachMessageModel>> watchMessages(String conversationId) =>
      _dao.watchMessages(conversationId).map((rows) => rows.map(toModel).toList());

  /// Marks a message's proposed plan change as applied.
  Future<void> markPlanChangeApplied(String messageId) => _dao.markChangeApplied(messageId);

  /// Records a satisfaction rating (thumbs up/down, SC-011).
  Future<void> rateSatisfaction(String messageId, {required bool thumbsUp}) =>
      _dao.updateMessageRating(messageId, thumbsUp);

  static CoachMessageModel toModel(CoachMessage row) => CoachMessageModel(
        id: row.id,
        conversationId: row.conversationId,
        role: row.role,
        content: row.content,
        contextScreen: row.contextScreen,
        contextExerciseSlug: row.contextExerciseSlug,
        planChangeProposed: row.planChangeProposed == null
            ? null
            : Map<String, dynamic>.from(jsonDecode(row.planChangeProposed!) as Map),
        planChangeApplied: row.planChangeApplied,
        satisfactionRating: row.satisfactionRating,
        createdAt: row.createdAt,
      );
}

final coachMessageRepositoryProvider = Provider<CoachMessageRepository>(
  (ref) => CoachMessageRepository(
    dao: CoachDao(ref.watch(appDatabaseProvider)),
    clock: ref.watch(clockProvider),
  ),
);
