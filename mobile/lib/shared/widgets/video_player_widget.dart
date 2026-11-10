import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_theme.dart';

/// Displays an exercise video.
///
/// - If [localPath] is provided (Pro offline download), plays from local file.
/// - Otherwise streams from [remoteUrl] (Cloudflare Stream HLS).
/// - If neither is available and the user is not Pro, shows the offline gate message.
class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({
    super.key,
    this.localPath,
    this.remoteUrl,
    required this.isPro,
    this.aspectRatio = 16 / 9,
    this.autoPlay = true,
    this.looping = true,
  });

  final String? localPath;
  final String? remoteUrl;
  final bool isPro;
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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(VideoPlayerWidget old) {
    super.didUpdateWidget(old);
    if (old.localPath != widget.localPath || old.remoteUrl != widget.remoteUrl) {
      _dispose();
      _initialize();
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    try {
      if (widget.localPath != null) {
        _controller = VideoPlayerController.file(File(widget.localPath!));
      } else if (widget.remoteUrl != null) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.remoteUrl!),
        );
      } else {
        return; // No source — show placeholder
      }

      await _controller!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _controller!,
        autoPlay: widget.autoPlay,
        looping: widget.looping,
        aspectRatio: widget.aspectRatio,
        showControls: true,
        allowMuting: true,
        allowFullScreen: true,
        showOptions: false,
      );

      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _dispose() {
    _chewieController?.dispose();
    _controller?.dispose();
    _chewieController = null;
    _controller = null;
    _error = false;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Offline and not Pro: show upgrade gate
    if (widget.localPath == null && widget.remoteUrl == null && !widget.isPro) {
      return _OfflinePlaceholder(aspectRatio: widget.aspectRatio);
    }

    if (_error) {
      return _ErrorPlaceholder(aspectRatio: widget.aspectRatio);
    }

    if (_chewieController == null) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }
}

class _OfflinePlaceholder extends StatelessWidget {
  const _OfflinePlaceholder({required this.aspectRatio});
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        color: AppColors.charcoalElevated,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: AppColors.onDarkSecondary, size: 32),
            SizedBox(height: 8),
            Text(
              'Offline video requires Tekto Pro',
              style: TextStyle(color: AppColors.onDarkSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.aspectRatio});
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        color: AppColors.charcoalElevated,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, color: AppColors.onDarkSecondary, size: 32),
            SizedBox(height: 8),
            Text(
              'Video unavailable',
              style: TextStyle(color: AppColors.onDarkSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
