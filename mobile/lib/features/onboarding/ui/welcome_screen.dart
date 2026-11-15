import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart' show AppSpacing;
import '../../../shared/widgets/bundled_clip.dart';

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
/// Plain background until the content workstream delivers `assets/video/welcome.mp4`.
class WelcomeVideo extends StatelessWidget {
  const WelcomeVideo({super.key});

  static const asset = 'assets/video/welcome.mp4';
  static String captionsAsset(String language) => 'assets/video/welcome_$language.vtt';

  @override
  Widget build(BuildContext context) => BundledClip(
        asset: asset,
        captionsAsset: captionsAsset,
        placeholder: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
      );
}
