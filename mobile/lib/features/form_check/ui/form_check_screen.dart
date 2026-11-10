import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tekto/core/theme/app_theme.dart';
import 'package:tekto/shared/services/form_check/cue_engine.dart';
import 'package:tekto/shared/services/form_check/form_check_service.dart';

/// Camera form check screen.
///
/// 1. Guided phone placement overlay shown first.
/// 2. Live camera preview with skeleton overlay, cue chips, rep counter.
/// 3. "Adjust lighting" message when pose confidence < 0.6.
/// 4. "Stop" ends session and navigates to [FormSummaryScreen].
///
/// Camera frames are NEVER transmitted or persisted (Principle II).
class FormCheckScreen extends ConsumerStatefulWidget {
  const FormCheckScreen({super.key, required this.exerciseSlug});

  final String exerciseSlug;

  @override
  ConsumerState<FormCheckScreen> createState() => _FormCheckScreenState();
}

class _FormCheckScreenState extends ConsumerState<FormCheckScreen> {
  FormCheckService? _service;
  CameraController? _cameraController;
  bool _framingShown = true;
  bool _sessionStarted = false;
  int _repCount = 0;
  List<FormCue> _currentCues = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    _service = FormCheckService(cameras: cameras);
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ---- Camera preview ----
            if (_cameraController != null &&
                _cameraController!.value.isInitialized)
              CameraPreview(_cameraController!),

            // ---- Framing overlay ----
            if (_framingShown) _FramingOverlay(onReady: _startSession),

            // ---- Live UI (shown during session) ----
            if (_sessionStarted) ...[
              // Cue chips
              Positioned(
                top: 32,
                left: 16,
                right: 16,
                child: _CueChips(cues: _currentCues),
              ),

              // Rep counter
              Positioned(
                top: 32,
                right: 16,
                child: _RepBadge(count: _repCount),
              ),
            ],

            // ---- Stop button ----
            if (_sessionStarted)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    height: AppSizes.minTapTarget,
                    child: ElevatedButton.icon(
                      onPressed: _stopSession,
                      icon: const Icon(Icons.stop_circle),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                    ),
                  ),
                ),
              ),

            // ---- Back button ----
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSession() async {
    setState(() => _framingShown = false);
    await _service!.startSession(exerciseSlug: widget.exerciseSlug);

    _cameraController = _service!._cameraController;

    _service!.repCountStream.listen((count) {
      if (mounted) setState(() => _repCount = count);
    });

    _service!.cueStream.listen((cues) {
      if (mounted) setState(() => _currentCues = cues);
    });

    setState(() => _sessionStarted = true);
  }

  Future<void> _stopSession() async {
    final summary = await _service!.stopSession();
    if (mounted) {
      context.push(
        '/form-check/${widget.exerciseSlug}/summary',
        extra: summary,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _FramingOverlay extends StatelessWidget {
  const _FramingOverlay({required this.onReady});
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black87,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 120, color: Colors.white54),
            const SizedBox(height: 24),
            const Text(
              'Position yourself so your full body is visible.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Place your phone 2–3 metres away.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onReady,
              child: const Text('Start form check'),
            ),
          ],
        ),
      );
}

class _CueChips extends StatelessWidget {
  const _CueChips({required this.cues});
  final List<FormCue> cues;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cues.map((cue) {
          final isAdjust = cue.key == 'adjust_lighting';
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAdjust
                  ? Colors.amber.withOpacity(0.9)
                  : Colors.red.withOpacity(0.85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              cue.textEn,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }).toList(),
      );
}

class _RepBadge extends StatelessWidget {
  const _RepBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          '$count reps',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}
