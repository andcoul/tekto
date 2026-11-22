// Friends, feed and leaderboard (FR-049, FR-050; contracts/backend-api.md §11, migration 016).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/muscle_groups.dart';

/// Fixed reactions (no user-written text in the feed, FR-049).
const kReactions = ['💪', '🔥', '👏'];

class FeedPost {
  const FeedPost({
    required this.workoutLogId,
    required this.userId,
    required this.displayName,
    required this.sessionNameEn,
    required this.sessionNameFr,
    required this.finishedAt,
    required this.durationMin,
    required this.volumeKg,
    required this.setCount,
    required this.recordSlugs,
    required this.groupSets,
    required this.reactions,
    this.myReaction,
  });

  factory FeedPost.fromRow(Map<String, dynamic> r) {
    final muscles = (r['muscles'] as Map?)?.cast<String, dynamic>() ?? const {};
    final groups = <String, int>{};
    muscles.forEach((m, n) {
      final g = muscleGroupOf(m);
      if (g != null) groups[g] = (groups[g] ?? 0) + (n as num).toInt();
    });
    return FeedPost(
      workoutLogId: r['workout_log_id'] as String,
      userId: r['user_id'] as String,
      displayName: (r['display_name'] as String?) ?? '',
      sessionNameEn: r['session_name_en'] as String? ?? '',
      sessionNameFr: r['session_name_fr'] as String? ?? '',
      finishedAt: DateTime.parse(r['finished_at'] as String).toLocal(),
      durationMin: (r['duration_min'] as num?)?.toInt() ?? 0,
      volumeKg: (r['volume_kg'] as num?)?.toDouble() ?? 0,
      setCount: (r['set_count'] as num?)?.toInt() ?? 0,
      recordSlugs: [for (final x in (r['records'] as List? ?? const [])) (x as Map)['exercise_slug'] as String],
      groupSets: groups,
      reactions: ((r['reactions'] as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toInt())),
      myReaction: r['my_reaction'] as String?,
    );
  }

  final String workoutLogId;
  final String userId;
  final String displayName;
  final String sessionNameEn;
  final String sessionNameFr;
  final DateTime finishedAt;
  final int durationMin;
  final double volumeKg;
  final int setCount;
  final List<String> recordSlugs;

  /// Sets per muscle group, for the muscle map.
  final Map<String, int> groupSets;
  final Map<String, int> reactions;
  final String? myReaction;

  /// Muscle map level 1–3 from sets (≥ 6 sets = 3).
  Map<String, int> get groupLevels => groupSets.map((g, n) => MapEntry(g, n >= 6 ? 3 : (n >= 3 ? 2 : 1)));
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.score,
    required this.lastWeek,
    this.lastTrainedAt,
  });
  factory LeaderboardEntry.fromRow(Map<String, dynamic> r) => LeaderboardEntry(
        userId: r['user_id'] as String,
        displayName: (r['display_name'] as String?) ?? (r['username'] as String?) ?? '',
        username: r['username'] as String?,
        score: (r['score'] as num).toInt(),
        lastWeek: (r['last_week'] as num).toInt(),
        lastTrainedAt: r['last_trained_at'] == null ? null : DateTime.parse(r['last_trained_at'] as String).toLocal(),
      );
  final String userId;
  final String displayName;
  final String? username;
  final int score;
  final int lastWeek;
  final DateTime? lastTrainedAt;
  int get change => score - lastWeek;
}

class FriendRequest {
  const FriendRequest({required this.friendshipId, required this.displayName});
  final String friendshipId;
  final String displayName;
}

/// The signed-in user's public identity.
class MyIdentity {
  const MyIdentity({this.username, this.displayName, required this.inviteCode});
  final String? username;
  final String? displayName;
  final String inviteCode;
  Uri get inviteLink => Uri.parse('https://tekto.app/invite/$inviteCode');
}

class UsernameTaken implements Exception {
  const UsernameTaken();
}

class UserNotFound implements Exception {
  const UserNotFound();
}

abstract class SocialApi {
  Future<List<FeedPost>> feed({DateTime? before});
  Future<void> react(String workoutLogId, String? emoji);
  Future<List<LeaderboardEntry>> leaderboard();

  /// Weekly scores per user, oldest week first.
  Future<Map<String, List<int>>> weeklyScores(List<String> userIds, {int weeks = 8});
  Future<List<FriendRequest>> requests();
  Future<void> accept(String friendshipId);
  Future<void> remove(String friendshipId);
  Future<void> addByUsername(String username);
  Future<void> acceptInvite(String code);
  Future<MyIdentity> me();
  Future<void> setUsername(String username);
}

class SupabaseSocialApi implements SocialApi {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  @override
  Future<List<FeedPost>> feed({DateTime? before}) async {
    final rows = await _db.rpc('friend_feed', params: {
      if (before != null) 'p_before': before.toUtc().toIso8601String(),
    }) as List;
    return [for (final r in rows) FeedPost.fromRow((r as Map).cast<String, dynamic>())];
  }

  @override
  Future<void> react(String workoutLogId, String? emoji) async {
    if (emoji == null) {
      await _db.from('workout_reactions').delete().eq('workout_log_id', workoutLogId).eq('user_id', _uid);
    } else {
      await _db.from('workout_reactions').upsert({'workout_log_id': workoutLogId, 'user_id': _uid, 'emoji': emoji});
    }
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard() async {
    final rows = await _db.rpc('friend_leaderboard') as List;
    return [for (final r in rows) LeaderboardEntry.fromRow((r as Map).cast<String, dynamic>())];
  }

  @override
  Future<Map<String, List<int>>> weeklyScores(List<String> userIds, {int weeks = 8}) async {
    final rows = await _db.rpc('weekly_scores', params: {'p_users': userIds, 'p_weeks': weeks}) as List;
    final out = <String, List<int>>{};
    final sorted = rows.cast<Map>().toList()
      ..sort((a, b) => (a['week_start'] as String).compareTo(b['week_start'] as String));
    for (final r in sorted) {
      out.putIfAbsent(r['user_id'] as String, () => []).add((r['score'] as num).toInt());
    }
    return out;
  }

  @override
  Future<List<FriendRequest>> requests() async {
    final rows = await _db.rpc('friend_requests') as List;
    return [
      for (final r in rows.cast<Map>())
        FriendRequest(
            friendshipId: r['friendship_id'] as String,
            displayName: (r['display_name'] as String?) ?? (r['username'] as String?) ?? ''),
    ];
  }

  @override
  Future<void> accept(String friendshipId) =>
      _db.from('friendships').update({'status': 'accepted'}).eq('id', friendshipId);

  @override
  Future<void> remove(String friendshipId) => _db.from('friendships').delete().eq('id', friendshipId);

  @override
  Future<void> addByUsername(String username) async {
    try {
      await _db.rpc('add_friend_by_username', params: {'p_username': username.trim().toLowerCase()});
    } on PostgrestException catch (e) {
      if (e.message.contains('USER_NOT_FOUND')) throw const UserNotFound();
      rethrow;
    }
  }

  @override
  Future<void> acceptInvite(String code) => _db.rpc('accept_invite', params: {'p_code': code});

  @override
  Future<MyIdentity> me() async {
    final r = await _db.from('users').select('username, display_name, invite_code').eq('id', _uid).single();
    return MyIdentity(
        username: r['username'] as String?,
        displayName: r['display_name'] as String?,
        inviteCode: r['invite_code'] as String);
  }

  @override
  Future<void> setUsername(String username) async {
    try {
      await _db.from('users').update({'username': username.trim().toLowerCase()}).eq('id', _uid);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const UsernameTaken();
      rethrow;
    }
  }
}

final socialApiProvider = Provider<SocialApi>((ref) => SupabaseSocialApi());
final feedProvider = FutureProvider.autoDispose<List<FeedPost>>((ref) => ref.watch(socialApiProvider).feed());
final leaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) => ref.watch(socialApiProvider).leaderboard());
final friendRequestsProvider =
    FutureProvider.autoDispose<List<FriendRequest>>((ref) => ref.watch(socialApiProvider).requests());
final myIdentityProvider = FutureProvider.autoDispose<MyIdentity>((ref) => ref.watch(socialApiProvider).me());

/// Valid username (migration 016 CHECK).
bool isValidUsername(String u) => RegExp(r'^[a-z0-9_.]{3,20}$').hasMatch(u.trim().toLowerCase());
