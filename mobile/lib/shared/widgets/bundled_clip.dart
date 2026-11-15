import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// A short clip bundled with the app (welcome, paywall value videos): muted, looping, with
/// captions in the app language, no network. Shows [placeholder] when the clip is missing or
/// cannot play (tests, or before the content workstream delivers the file).
class BundledClip extends StatefulWidget {
  const BundledClip({super.key, required this.asset, required this.captionsAsset, required this.placeholder});

  final String asset;

  /// WebVTT asset for a language code, e.g. `assets/video/welcome_fr.vtt`.
  final String Function(String languageCode) captionsAsset;
  final Widget placeholder;

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
    if (!_ready || controller == null) return widget.placeholder;
    return Stack(fit: StackFit.expand, children: [
      FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: ClosedCaption(text: controller.value.caption.text),
      ),
    ]);
  }
}
