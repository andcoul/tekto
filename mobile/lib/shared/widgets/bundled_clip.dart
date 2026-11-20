import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart' show AppColors;

/// A short clip bundled with the app (welcome, paywall value videos): muted, looping, with
/// captions in the app language, no network. Shows [placeholder] when the clip is missing or
/// cannot play (tests, or before the content workstream delivers the file).
class BundledClip extends StatefulWidget {
  const BundledClip({
    super.key,
    required this.asset,
    required this.captionsAsset,
    required this.placeholder,
    this.captionAlignment = Alignment.bottomCenter,
    this.scrim,
  });

  final String asset;

  /// WebVTT asset for a language code, e.g. `assets/video/welcome_fr.vtt`.
  final String Function(String languageCode) captionsAsset;
  final Widget placeholder;

  /// Where the caption sits; move it when the screen puts its own text over the bottom.
  final AlignmentGeometry captionAlignment;

  /// Drawn over the clip (and the placeholder) but under the caption, e.g. a fade for the screen's text.
  final Widget? scrim;

  @override
  State<BundledClip> createState() => _BundledClipState();
}

class _BundledClipState extends State<BundledClip> {
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
      final captions = await rootBundle.loadString(widget.captionsAsset(language));
      final controller = VideoPlayerController.asset(
        widget.asset,
        closedCaptionFile: Future.value(WebVTTCaptionFile(captions)),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() => _ready = true);
    } on Object {
      // No clip or no player: the placeholder stays.
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
    final scrim = widget.scrim;
    if (!_ready || controller == null) {
      return scrim == null ? widget.placeholder : Stack(fit: StackFit.expand, children: [widget.placeholder, scrim]);
    }
    return Stack(fit: StackFit.expand, children: [
      FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
      if (scrim != null) scrim,
      Align(
        alignment: widget.captionAlignment,
        // The caption changes as the clip plays, so it listens to the player.
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: controller,
          builder: (_, value, __) => ClipCaption(text: value.caption.text),
        ),
      ),
    ]);
  }
}

/// One caption line over a clip. Unlike [ClosedCaption], it takes only the space it needs, so the
/// parent decides where it sits. Empty between cues.
class ClipCaption extends StatelessWidget {
  const ClipCaption({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppColors.ink.withValues(alpha: .72), borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.frost, fontSize: 15, height: 1.3),
          ),
        ),
      ),
    );
  }
}
