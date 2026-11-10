// T021 — written before the VideoPlayerWidget update (Constitution V).
// Platform video playback is not available in widget tests, so source selection is tested
// through the pure resolveVideoSource()/captionSourceFor() functions, and the offline notice
// is tested by pumping the widget.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekto/core/l10n/gen/app_localizations.dart';
import 'package:tekto/shared/widgets/video_player_widget.dart';

void main() {
  group('resolveVideoSource', () {
    test('Pro with a download plays the local file, online or offline', () {
      for (final online in [true, false]) {
        final s = resolveVideoSource(isPro: true, isOnline: online, localPath: '/v/squat.mp4', remoteUrl: 'https://v/squat.m3u8');
        expect(s.kind, VideoSourceKind.local);
        expect(s.location, '/v/squat.mp4');
      }
    });

    test('online without a download streams the remote URL for everyone', () {
      for (final pro in [true, false]) {
        final s = resolveVideoSource(isPro: pro, isOnline: true, localPath: null, remoteUrl: 'https://v/squat.m3u8');
        expect(s.kind, VideoSourceKind.remote);
        expect(s.location, 'https://v/squat.m3u8');
      }
    });

    test('free user offline gets the Pro notice — even if a file is left from a past Pro period', () {
      for (final local in [null, '/v/squat.mp4']) {
        final s = resolveVideoSource(isPro: false, isOnline: false, localPath: local, remoteUrl: 'https://v/squat.m3u8');
        expect(s.kind, VideoSourceKind.proRequired);
      }
    });

    test('free user online with a leftover file streams instead of playing the file', () {
      final s = resolveVideoSource(isPro: false, isOnline: true, localPath: '/v/squat.mp4', remoteUrl: 'https://v/squat.m3u8');
      expect(s.kind, VideoSourceKind.remote);
    });

    test('Pro offline without a download, or no URL at all, is unavailable', () {
      expect(resolveVideoSource(isPro: true, isOnline: false, localPath: null, remoteUrl: 'https://v').kind,
          VideoSourceKind.unavailable);
      expect(resolveVideoSource(isPro: true, isOnline: true, localPath: null, remoteUrl: null).kind,
          VideoSourceKind.unavailable);
    });
  });

  group('captionSourceFor', () {
    const remote = {'en': 'https://v/en.vtt', 'fr': 'https://v/fr.vtt'};
    const local = {'en': '/c/en.vtt', 'fr': '/c/fr.vtt'};

    test('uses the user language and the same source as the video', () {
      expect(captionSourceFor(VideoSourceKind.remote, 'fr', remote: remote, local: local), 'https://v/fr.vtt');
      expect(captionSourceFor(VideoSourceKind.local, 'fr', remote: remote, local: local), '/c/fr.vtt');
      expect(captionSourceFor(VideoSourceKind.local, 'en', remote: remote, local: local), '/c/en.vtt');
    });

    test('falls back to English, then null', () {
      expect(captionSourceFor(VideoSourceKind.remote, 'fr', remote: const {'en': 'https://v/en.vtt'}, local: const {}),
          'https://v/en.vtt');
      expect(captionSourceFor(VideoSourceKind.proRequired, 'en', remote: remote, local: local), isNull);
    });
  });

  testWidgets('free user offline sees an inline notice that does not block the workout', (tester) async {
    var setLogged = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(children: [
          const VideoPlayerWidget(isPro: false, isOnline: false, remoteUrl: 'https://v/squat.m3u8'),
          ElevatedButton(onPressed: () => setLogged = true, child: const Text('Log set')),
        ]),
      ),
    ));

    expect(find.text('Offline video requires Tekto Pro'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Log set'));
    expect(setLogged, isTrue, reason: 'the notice must not block other actions');
  });

  testWidgets('the notice is localized', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: VideoPlayerWidget(isPro: false, isOnline: false, remoteUrl: 'https://v')),
    ));
    expect(find.text('La vidéo hors ligne nécessite Tekto Pro'), findsOneWidget);
  });
}
