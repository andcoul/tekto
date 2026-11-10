import 'dart:async';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:tekto/shared/services/form_check/cue_engine.dart';
import 'package:tekto/shared/services/form_check/form_score_calculator.dart';
import 'package:tekto/shared/services/form_check/pose_analyzer.dart';
import 'package:tekto/shared/services/form_check/rep_counter.dart';

/// Orchestrates the camera → ML Kit → PoseAnalyzer → RepCounter → CueEngine
/// pipeline.
///
/// Camera frames are NEVER written to disk or transmitted (Principle II:
/// memory-only processing).
///
/// Usage:
///   await service.startSession(exerciseSlug: 'squat');
///   // listen to cueStream and repCountStream for live feedback
///   final summary = await service.stopSession();
class FormCheckService {
  FormCheckService({
    required List<CameraDescription> cameras,
    CueEngine? cueEngine,
    FormScoreCalculator? scoreCalculator,
  })  : _cameras = cameras,
        _cueEngine = cueEngine ?? const CueEngine(),
        _scoreCalculator = scoreCalculator ??
            FormScoreCalculator(cueEngine: cueEngine ?? const CueEngine());

  final List<CameraDescription> _cameras;
  final CueEngine _cueEngine;
  final FormScoreCalculator _scoreCalculator;
  final PoseAnalyzer _poseAnalyzer = const PoseAnalyzer();

  CameraController? _cameraController;
  PoseDetector? _poseDetector;
  RepCounter? _repCounter;

  final _cueController = StreamController<List<FormCue>>.broadcast();
  final _repController = StreamController<int>.broadcast();

  final _frames = <FormFrameResult>[];
  bool _isSessionActive = false;

  Stream<List<FormCue>> get cueStream => _cueController.stream;
  Stream<int> get repCountStream => _repController.stream;
  bool get isSessionActive => _isSessionActive;

  /// Starts the camera pipeline for [exerciseSlug].
  Future<void> startSession({required String exerciseSlug}) async {
    if (_cameras.isEmpty) throw StateError('No cameras available');

    _repCounter = RepCounter(liftKey: exerciseSlug);
    _frames.clear();
    _isSessionActive = true;

    // Initialise pose detector (stream mode for live feedback)
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );

    // Use back camera
    final camera = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await _cameraController!.initialize();

    await _cameraController!.startImageStream(_processFrame);
  }

  /// Stops the pipeline and returns a [FormSetSummary].
  Future<FormSetSummary> stopSession() async {
    _isSessionActive = false;
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    _cameraController = null;

    await _poseDetector?.close();
    _poseDetector = null;

    final summary = _scoreCalculator.calculate(
      frames: List.unmodifiable(_frames),
      liftKey: _repCounter?.liftKey ?? '',
      language: 'en',
      repCount: _repCounter?.repCount ?? 0,
    );

    return summary;
  }

  void dispose() {
    _isSessionActive = false;
    _cameraController?.dispose();
    _poseDetector?.close();
    _cueController.close();
    _repController.close();
  }

  // ---------------------------------------------------------------------------
  // Frame processing pipeline (memory-only — Principle II)
  // ---------------------------------------------------------------------------

  Future<void> _processFrame(CameraImage image) async {
    if (!_isSessionActive || _poseDetector == null || _repCounter == null) {
      return;
    }

    final inputImage = _cameraImageToInputImage(image);
    if (inputImage == null) return;

    final poses = await _poseDetector!.processImage(inputImage);
    if (poses.isEmpty) return;

    final pose = poses.first;
    final result = _poseAnalyzer.analyze(pose, _repCounter!.liftKey);

    _frames.add(result);

    // Rep counting
    final repCompleted = _repCounter!.update(
      result.jointAngleSnapshot['knee_angle'] ?? 180,
    );
    if (repCompleted) {
      _repController.add(_repCounter!.repCount);
    }

    // Cue evaluation
    final cues = _cueEngine.evaluate(result);
    _cueController.add(cues);
  }

  InputImage? _cameraImageToInputImage(CameraImage image) {
    // Convert NV21 CameraImage to ML Kit InputImage
    final bytes = image.planes.first.bytes;
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }
}
