// FR-049, FR-050, FR-052, FR-054 (2026-11-21): focus picker, feed reactions, friends, support chat.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/di/providers.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/features/onboarding/ui/focus_muscles_picker.dart';
import 'package:tekto/features/social/data/social_api.dart';
import 'package:tekto/features/social/ui/feed_screen.dart';
import 'package:tekto/features/social/ui/friends_screen.dart';
import 'package:tekto/features/support/data/support_api.dart';
import 'package:tekto/features/support/ui/support_chat_screen.dart';
import 'package:tekto/features/workout/domain/workout_providers.dart';

class _FakeSocial implements SocialApi {
  final reacted = <(String, String?)>[];
  final added = <String>[];
  bool failReact = false;
  @override
  Future<List<FeedPost>> feed({DateTime? before}) async => [
        FeedPost.fromRow({
          'workout_log_id': 'w1', 'user_id': 'maya', 'display_name': 'Maya Koné', 'session_name_en': 'Lower B', //
          'session_name_fr': 'Bas B',
          'finished_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          'duration_min': 48, 'volume_kg': 8920, 'set_count': 21,
          'records': [
            {'exercise_slug': 'hip-thrust', 'weight_kg': 100, 'reps': 8}
          ],
          'muscles': {'glutes': 9, 'hamstrings': 6}, 'reactions': {'💪': 2}, 'my_reaction': null,
        }),
      ];
  @override
  Future<void> react(String id, String? emoji) async {
    if (failReact) throw Exception('offline');
    reacted.add((id, emoji));
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard() async => [
        LeaderboardEntry(userId: 'maya', displayName: 'Maya Koné', username: 'maya', score: 268, lastWeek: 254),
        LeaderboardEntry(userId: 'me', displayName: 'Sam', username: 'sam', score: 241, lastWeek: 232),
      ];
  @override
  Future<Map<String, List<int>>> weeklyScores(List<String> ids, {int weeks = 8}) async => {
        for (final id in ids) id: [200, 210, 220, 230, 240, 241, 245, 250]
      };
  @override
  Future<List<FriendRequest>> requests() async => const [];
  @override
  Future<void> accept(String id) async {}
  @override
  Future<void> remove(String id) async {}
  @override
  Future<void> addByUsername(String u) async {
    if (u == 'nobody') throw const UserNotFound();
    added.add(u);
  }

  @override
  Future<void> acceptInvite(String code) async {}
  @override
  Future<MyIdentity> me() async => const MyIdentity(username: 'sam', inviteCode: 'abc123');
  @override
  Future<void> setUsername(String u) async {}
}

class _FakeSupport implements SupportApi {
  final sent = <(String, bool)>[];
  @override
  Stream<List<SupportMessage>> watch() => Stream.value(const []);
  @override
  Future<SupportSendResult> send(String body, {bool wantHuman = false}) async {
    sent.add((body, wantHuman));
    final now = DateTime.now();
    return SupportSendResult(waitingForAgent: wantHuman, messages: [
      SupportMessage(id: 'u${sent.length}', sender: 'user', body: body, createdAt: now),
      SupportMessage(
          id: 'a${sent.length}',
          sender: 'ai',
          body: wantHuman ? 'A person will reply.' : 'Settings › Subscription › Restore.',
          createdAt: now.add(const Duration(seconds: 1))),
    ]);
  }
}

Widget _app(Widget home, List overrides) => ProviderScope(
      overrides: [...overrides.cast()],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  setUp(() {});

  testWidgets('focus picker: 15 tiles, at most 2 selected', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var selected = <String>['glutes'];
    await tester.pumpWidget(_app(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: FocusMusclesPicker(
              selected: selected,
              onToggle: (g) => setState(() {
                if (selected.contains(g)) {
                  selected = [...selected]..remove(g);
                } else if (selected.length < 2) {
                  selected = [...selected, g];
                }
              }),
            ),
          ),
        ),
        const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-chest')), findsOneWidget);
    expect(find.text('1 / 2 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('focus-chest')));
    await tester.pump();
    expect(find.text('2 / 2 selected'), findsOneWidget);
  });

  testWidgets('feed: a friend post shows stats and a record; reacting calls the API', (tester) async {
    final social = _FakeSocial();
    await tester.pumpWidget(_app(const FeedScreen(), [
      socialApiProvider.overrideWithValue(social),
      currentUserIdProvider.overrideWithValue('me'),
      userPrefsProvider.overrideWith((ref) async => throw UnimplementedError()),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Maya Koné'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('New record'), findsOneWidget);
    expect(find.text('You are #2 of 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('react-w1-🔥')));
    await tester.pump();
    expect(social.reacted, [('w1', '🔥')]);
    expect(find.text('🔥 1'), findsOneWidget);
  });

  testWidgets('feed: a failed reaction is undone', (tester) async {
    final social = _FakeSocial()..failReact = true;
    await tester.pumpWidget(_app(const FeedScreen(), [
      socialApiProvider.overrideWithValue(social),
      currentUserIdProvider.overrideWithValue('me'),
      userPrefsProvider.overrideWith((ref) async => throw UnimplementedError()),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('react-w1-💪')));
    await tester.pump();
    await tester.pump();
    expect(find.text('💪 2'), findsOneWidget);
  });

  testWidgets('friends: leaderboard with weekly change, and adding by username', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final social = _FakeSocial();
    await tester.pumpWidget(_app(const FriendsScreen(), [
      socialApiProvider.overrideWithValue(social),
      currentUserIdProvider.overrideWithValue('me'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('+14 this week'), findsOneWidget);
    expect(find.text('Compare progress'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('friends-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('friend-username')), 'Maya');
    await tester.tap(find.text('Send request'));
    await tester.pumpAndSettle();
    expect(social.added, ['Maya']);
    expect(find.text('Request sent'), findsOneWidget);
  });

  testWidgets('support: the AI answers; "Talk to a person" hands over', (tester) async {
    final support = _FakeSupport();
    await tester.pumpWidget(_app(const SupportChatScreen(), [supportApiProvider.overrideWithValue(support)]));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('support-input')), 'How do I restore?');
    await tester.tap(find.byKey(const ValueKey('support-send')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Settings › Subscription › Restore.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('support-human')));
    await tester.pump();
    await tester.pump();
    expect(support.sent.last, ("I'd like to talk to a person.", true));
    expect(find.textContaining('will reply here as soon as possible'), findsOneWidget);
    expect(find.byKey(const ValueKey('support-human')), findsNothing);
  });
}
