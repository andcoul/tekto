import 'dart:convert';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/app_theme.dart';

enum VideoSourceKind { local, remote, proRequired, unavailable }

class VideoSource {
  const VideoSource(this.kind, [this.location]);
  final VideoSourceKind kind;

  /// File path for [VideoSourceKind.local], URL for [VideoSourceKind.remote].
  final String? location;
}

/// Picks what to play (Constitution I v2.0.0: offline video is a Pro entitlement).
///
/// - Pro + downloaded file → local file (online or offline).
/// - Online → stream, for everyone (a file left over from a past Pro period is not used).
/// - Offline, not Pro → inline "offline video requires Pro" notice.
/// - Otherwise (Pro offline without a download, or no URL) → unavailable.
VideoSource resolveVideoSource({
  required bool isPro,
  required bool isOnline,
  required String? localPath,
  required String? remoteUrl,
}) {
  if (isPro && localPath != null) return VideoSource(VideoSourceKind.local, localPath);
  if (isOnline && remoteUrl != null) return VideoSource(VideoSourceKind.remote, remoteUrl);
  if (!isOnline && !isPro) return const VideoSource(VideoSourceKind.proRequired);
  return const VideoSource(VideoSourceKind.unavailable);
}

/// Caption track for [language] from the same source as the video, falling back to English.
String? captionSourceFor(
  VideoSourceKind kind,
  String language, {
  required Map<String, String> remote,
  required Map<String, String> local,
}) {
  final tracks = switch (kind) {
    VideoSourceKind.local => local,
    VideoSourceKind.remote => remote,
    _ => const <String, String>{},
  };
  return tracks[language] ?? tracks['en'];
}

/// Looping exercise video with WebVTT captions (FR-014, FR-035).
///
/// Captions are shown by default (Flutter exposes no OS caption preference); the player's
/// CC control turns them off.
class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({
    super.key,
    required this.isPro,
    required this.isOnline,
    this.localPath,
    this.remoteUrl,
    this.remoteCaptions = const {},
    this.localCaptions = const {},
    this.aspectRatio = 16 / 9,
    this.autoPlay = true,
    this.looping = true,
  });

  final bool isPro;
  final bool isOnline;
  final String? localPath;
  final String? remoteUrl;

  /// Caption URLs keyed by language code ('en', 'fr').
  final Map<String, String> remoteCaptions;

  /// Downloaded caption file paths keyed by language code.
  final Map<String, String> localCaptions;
  final double aspectRatio;
  final bool autoPlay;
  final bool looping;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _error = false;
  String? _initializedFor;

  VideoSource get _source => resolveVideoSource(
        isPro: widget.isPro,
        isOnline: widget.isOnline,
        localPath: widget.localPath,
        remoteUrl: widget.remoteUrl,
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeIfNeeded();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget old) {
    super.didUpdateWidget(old);
    _initializeIfNeeded();
  }

  void _initializeIfNeeded() {
    final source = _source;
    final language = Localizations.localeOf(context).languageCode;
    final key = '${source.kind}|${source.location}|$language';
    if (key == _initializedFor) return;
    _initializedFor = key;
    _disposePlayer();
    if (source.kind == VideoSourceKind.local || source.kind == VideoSourceKind.remote) {
      _initialize(source, language);
    }
  }

  Future<void> _initialize(VideoSource source, String language) async {
    try {
      final controller = source.kind == VideoSourceKind.local
          ? VideoPlayerController.file(File(source.location!))
          : VideoPlayerController.networkUrl(Uri.parse(source.location!));
      _controller = controller;
      await controller.initialize();

      final captionLocation = captionSourceFor(
        source.kind,
        language,
        remote: widget.remoteCaptions,
        local: widget.localCaptions,
      );
      final subtitles = captionLocation == null ? null : await _loadSubtitles(source.kind, captionLocation);

      if (!mounted || _controller != controller) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: widget.autoPlay,
          looping: widget.looping,
          aspectRatio: widget.aspectRatio,
          showControls: true,
          allowMuting: true,
          allowFullScreen: true,
          showOptions: false,
          subtitle: subtitles,
          showSubtitles: subtitles != null,
        );
      });
    } on Exception {
      if (mounted) setState(() => _error = true);
    }
  }

  /// Loads a WebVTT track; a missing or unreadable track never blocks the video.
  static Future<Subtitles?> _loadSubtitles(VideoSourceKind kind, String location) async {
    try {
      final contents = kind == VideoSourceKind.local
          ? await File(location).readAsString()
          : await _httpGetString(Uri.parse(location));
      final captions = WebVTTCaptionFile(contents).captions;
      return Subtitles([
        for (final c in captions) Subtitle(index: c.number, start: c.start, end: c.end, text: c.text),
      ]);
    } on Exception {
      return null;
    }
  }

  static Future<String> _httpGetString(Uri uri) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: uri);
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  void _disposePlayer() {
    _chewieController?.dispose();
    _controller?.dispose();
    _chewieController = null;
    _controller = null;
    _error = false;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_source.kind) {
      case VideoSourceKind.proRequired:
        return _Placeholder(aspectRatio: widget.aspectRatio, icon: Icons.lock_outline, text: l10n.libraryOfflineProRequired);
      case VideoSourceKind.unavailable:
        return _Placeholder(aspectRatio: widget.aspectRatio, icon: Icons.play_circle_outline, text: l10n.libraryVideoUnavailable);
      case VideoSourceKind.local:
      case VideoSourceKind.remote:
        break;
    }

    if (_error) {
      return _Placeholder(aspectRatio: widget.aspectRatio, icon: Icons.play_circle_outline, text: l10n.libraryVideoUnavailable);
    }
    if (_chewieController == null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    return AspectRatio(aspectRatio: widget.aspectRatio, child: Chewie(controller: _chewieController!));
  }
}

/// Inline placeholder — never a modal, so the workout around it stays usable.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.aspectRatio, required this.icon, required this.text});
  final double aspectRatio;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        color: AppColors.charcoalElevated,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.onDarkSecondary, size: 32),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(color: AppColors.onDarkSecondary, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
