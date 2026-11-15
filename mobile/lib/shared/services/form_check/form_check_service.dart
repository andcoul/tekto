import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'cue_engine.dart';
import 'form_check_pipeline.dart';
import 'form_score_calculator.dart';
import 'pose_analyzer.dart';

/// Camera → ML Kit → [PoseAnalyzer] → [FormCheckPipeline].
///
/// Camera frames live only in memory for the time it takes to analyse them: they are never
/// written to disk or sent anywhere (Constitution II). Frames that arrive while the previous
/// one is still being analysed are dropped, so latency does not build up.
///
/// Usage:
///   await service.startSession(liftKey: 'squat');
///   service.outcomes.listen(...);   // live cues + rep count
///   final summary = await service.stopSession(language: 'fr');
class FormCheckService {
  FormCheckService({required List<CameraDescription> cameras, CueEngine cueEngine = const CueEngine()})
      : _cameras = cameras,
        _cueEngine = cueEngine;

  final List<CameraDescription> _cameras;
  final CueEngine _cueEngine;
  final PoseAnalyzer _poseAnalyzer = const PoseAnalyzer();

  CameraController? _cameraController;
  CameraDescription? _camera;
  PoseDetector? _poseDetector;
  FormCheckPipeline? _pipeline;
  bool _busy = false;

  final _outcomes = StreamController<FrameOutcome>.broadcast();

  /// One event per analysed frame.
  Stream<FrameOutcome> get outcomes => _outcomes.stream;

  /// For [CameraPreview]; null until [startSession] has initialised the camera.
  CameraController? get cameraController => _cameraController;

  bool get isSessionActive => _pipeline != null;

  /// Opens the back camera and starts analysing frames for [liftKey] (a launch lift key,
  /// see `RepCounter.launchLifts`).
  Future<void> startSession({required String liftKey}) async {
    if (_cameras.isEmpty) throw StateError('No cameras available');
    _pipeline = FormCheckPipeline(liftKey: liftKey, cueEngine: _cueEngine);
    _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));

    final camera = _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => _cameras.first);
    _camera = camera;
    final controller = CameraController(
      camera,
      ResolutionPreset.medium, // enough for pose landmarks; keeps per-frame work low
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
    );
    _cameraController = controller;
    await controller.initialize();
    await controller.startImageStream(_processFrame);
  }

  /// Stops the camera and returns the post-set summary.
  Future<FormSetSummary> stopSession({required String language}) async {
    final pipeline = _pipeline;
    _pipeline = null;
    await _closeCamera();
    if (pipeline == null) {
      return const FormSetSummary(score: 100, cuesShown: [], topTipEn: '', topTipFr: '', repCount: 0);
    }
    final median = pipeline.medianProcessingMs;
    if (kDebugMode && median != null) {
      // Performance Standards: median per-frame processing < 150 ms.
      debugPrint('[FormCheck] ${pipeline.liftKey}: median frame processing ${median.toStringAsFixed(0)} ms');
    }
    return pipeline.finish(language: language);
  }

  Future<void> dispose() async {
    _pipeline = null;
    await _closeCamera();
    await _outcomes.close();
  }

  Future<void> _closeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
      await controller.dispose();
    }
    await _poseDetector?.close();
    _poseDetector = null;
  }

  Future<void> _processFrame(CameraImage image) async {
    final pipeline = _pipeline, detector = _poseDetector;
    if (pipeline == null || detector == null || _busy) return; // drop the frame
    _busy = true;
    final stopwatch = Stopwatch()..start();
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final poses = await detector.processImage(input);
      if (poses.isEmpty || !identical(pipeline, _pipeline)) return;
      final result = _poseAnalyzer.analyze(poses.first, pipeline.liftKey);
      final outcome = pipeline.add(result, processing: stopwatch.elapsed);
      if (!_outcomes.isClosed) _outcomes.add(outcome);
    } finally {
      _busy = false;
    }
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null || image.planes.isEmpty) return null;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (rotation == null || format == null) return null;
    // One plane for NV21 (Android) and BGRA8888 (iOS), as requested above.
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
