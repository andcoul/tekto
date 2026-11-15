import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart' show AppSpacing;

/// First screen for signed-out users (FR-043, T125): a short bundled clip, the value promise,
/// then sign-in. The only onboarding screen shown before sign-in; works with no network.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const WelcomeVideo(),
          // Fades the bottom into the background so the copy stays readable over any frame.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Theme.of(context).scaffoldBackgroundColor],
                stops: [0.35, 0.85],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(onPressed: () => context.go('/auth'), child: Text(l10n.welcomeSkip)),
                  ),
                  const Spacer(),
                  Text(l10n.welcomeTitle, style: text.displayMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.welcomeBody, style: text.bodyLarge),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton(onPressed: () => context.go('/auth'), child: Text(l10n.welcomeGetStarted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Muted, looping welcome clip bundled with the app, with captions in the app language.
/// Falls back to a plain background when the clip is missing or cannot play (tests, or before
/// the content workstream delivers `assets/video/welcome.mp4`).
class WelcomeVideo extends StatefulWidget {
  const WelcomeVideo({super.key});

  static const asset = 'assets/video/welcome.mp4';
  static String captionsAsset(String language) => 'assets/video/welcome_$language.vtt';

  @override
  State<WelcomeVideo> createState() => _WelcomeVideoState();
}

class _WelcomeVideoState extends State<WelcomeVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _start(Localizations.localeOf(context).languageCode);
  }

  Future<void> _start(String language) async {
    try {
      final captions = await rootBundle.loadString(WelcomeVideo.captionsAsset(language));
      final controller = VideoPlayerController.asset(
        WelcomeVideo.asset,
        closedCaptionFile: Future.value(WebVTTCaptionFile(captions)),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() => _ready = true);
    } on Object {
      // No clip or no player: the screen still works on the plain background.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null) return ColoredBox(color: Theme.of(context).scaffoldBackgroundColor);
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 96),
            child: ClosedCaption(text: controller.value.caption.text),
          ),
        ),
      ],
    );
  }
}
