// Weekly training score (FR-050): same formula as weekly_score() in migration 016.
import 'dart:math';

/// 20 per finished session (at most 7), 1 per logged set, 10 per record (one per exercise per workout).
int weeklyScore({required int sessions, required int sets, required int records}) =>
    min(sessions, 7) * 20 + sets + records * 10;

/// Monday 00:00 of the week containing [day] (local calendar).
DateTime weekStartOf(DateTime day) => DateTime(day.year, day.month, day.day).subtract(Duration(days: day.weekday - 1));
