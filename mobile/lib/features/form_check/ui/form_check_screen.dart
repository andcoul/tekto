import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/form_check/cue_engine.dart';
import '../../../shared/services/form_check/form_check_pipeline.dart';
import '../../../shared/services/form_check/form_check_service.dart';
import '../../../shared/widgets/pro_gate_widget.dart';
import '../../subscription/ui/paywall_screen.dart';
import '../../workout/domain/workout_controller.dart';
import '../data/form_check_repository.dart';
import '../domain/form_check_free_try_service.dart';
import '../domain/form_check_gate.dart';
import 'beta_badge.dart';

/// Opens the form check for [exerciseSlug], or the paywall (a bottom sheet during a workout)
/// when a free user already used this lift's try — so the workout screen is never left.
Future<void> openFormCheck(BuildContext context, WidgetRef ref, String exerciseSlug) async {
  // Keep the auto-dispose gate alive while it loads (nothing else listens to it here).
  final keepAlive = ref.listenManual(formCheckGateProvider(exerciseSlug), (_, __) {});
  final FormCheckGate gate;
  try {
    gate = await ref.read(formCheckGateProvider(exerciseSlug).future);
  } finally {
    keepAlive.close();
  }
  if (!context.mounted) return;
  if (gate.supported && !gate.access.allowed) {
    await showProPaywall(context, ref, PaywallFeature.formCheck);
    return;
  }
  await context.push('/form-check/$exerciseSlug');
}

/// Camera form check (US4).
///
/// 1. Gate: Pro, a free user's first try on this lift, or the paywall (FR-029).
/// 2. Guided phone placement, then the live camera with up to 3 cues and a rep counter.
/// 3. "Adjust lighting" replaces cues when tracking confidence is low (FR-025).
/// 4. "Stop" saves the summary (never any image) and opens [FormSummaryScreen].
class FormCheckScreen extends ConsumerWidget {
  const FormCheckScreen({super.key, required this.exerciseSlug});

  final String exerciseSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final gate = ref.watch(formCheckGateProvider(exerciseSlug));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [Text(l.formCheckTitle), const SizedBox(width: 8), const BetaBadge()]),
      ),
      body: SafeArea(
        child: gate.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _Message(text: l.formCheckNotSupported),
          data: (g) {
            if (!g.supported) return _Message(text: l.formCheckNotSupported);
            if (!g.access.allowed) return _BlockedView(l: l);
            return _LiveFormCheck(exerciseSlug: exerciseSlug, liftKey: g.liftKey!, access: g.access);
          },
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
        ),
      );
}

class _BlockedView extends StatelessWidget {
  const _BlockedView({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.white54),
              const SizedBox(height: AppSpacing.base),
              Text(l.formCheckFreeTryUsed,
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: AppSpacing.lg),
              // Free users only reach this view; the gate opens the paywall on tap.
              ProGateWidget(
                feature: PaywallFeature.formCheck,
                child: ElevatedButton(onPressed: () {}, child: Text(l.formCheckUnlock)),
              ),
            ],
          ),
        ),
      );
}

class _LiveFormCheck extends ConsumerStatefulWidget {
  const _LiveFormCheck({required this.exerciseSlug, required this.liftKey, required this.access});

  final String exerciseSlug;
  final String liftKey;
  final FormCheckAccess access;

  @override
  ConsumerState<_LiveFormCheck> createState() => _LiveFormCheckState();
}

class _LiveFormCheckState extends ConsumerState<_LiveFormCheck> {
  /// Cues stay up at least this long, so a one-frame cue can still be read.
  static const _cueHold = Duration(milliseconds: 1500);

  FormCheckService? _service;
  StreamSubscription<FrameOutcome>? _outcomes;
  bool _starting = false;
  bool _cameraFailed = false;
  bool _stopping = false;
  int _repCount = 0;
  List<FormCue> _cues = const [];
  DateTime _cuesShownAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _outcomes?.cancel();
    unawaited(_service?.dispose());
    super.dispose();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final cameras = await ref.read(formCheckCamerasProvider.future);
      final service = FormCheckService(cameras: cameras);
      _service = service;
      _outcomes = service.outcomes.listen(_onOutcome);
      await service.startSession(liftKey: widget.liftKey);
      if (mounted) setState(() => _starting = false);
    } on Object {
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  void _onOutcome(FrameOutcome o) {
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _repCount = o.repCount;
      if (o.cues.isNotEmpty) {
        _cues = o.cues;
        _cuesShownAt = now;
      } else if (now.difference(_cuesShownAt) > _cueHold) {
        _cues = const [];
      }
    });
  }

  Future<void> _stop() async {
    final service = _service;
    if (service == null || _stopping) return;
    setState(() => _stopping = true);
    final language = Localizations.localeOf(context).languageCode;
    final summary = await service.stopSession(language: language);
    final userId = ref.read(currentUserIdProvider);
    // A set where nothing was tracked does not use up the free try.
    if (userId != null && summary.repCount > 0) {
      final workout = ref.read(workoutControllerProvider);
      await ref.read(formCheckRepositoryProvider).saveSession(
            userId: userId,
            exerciseSlug: widget.exerciseSlug,
            summary: summary,
            wasFreeTry: widget.access.wasFreeTry,
            workoutLogId: workout.isWorkoutActive ? workout.workoutLogId : null,
          );
      ref.invalidate(formCheckGateProvider(widget.exerciseSlug));
    }
    if (mounted) context.pushReplacement('/form-check/${widget.exerciseSlug}/summary', extra: summary);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = _service?.cameraController;
    if (_cameraFailed) return _Message(text: l.formCheckNoCamera);
    if (_service == null) {
      return _PlacementGuide(l: l, freeTry: widget.access.wasFreeTry, onStart: _starting ? null : _start);
    }
    final lang = Localizations.localeOf(context).languageCode;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null && controller.value.isInitialized) CameraPreview(controller),
        if (_starting) const Center(child: CircularProgressIndicator()),
        Positioned(
          top: AppSpacing.base,
          left: AppSpacing.base,
          right: 96,
          child: _CueChips(cues: _cues, language: lang, adjustLighting: l.formCheckAdjustLighting),
        ),
        Positioned(top: AppSpacing.base, right: AppSpacing.base, child: _RepBadge(text: l.formCheckReps(_repCount))),
        Positioned(
          bottom: AppSpacing.xl,
          left: 0,
          right: 0,
          child: Center(
            child: SizedBox(
              height: AppSizes.minTapTarget,
              child: ElevatedButton.icon(
                onPressed: _starting || _stopping ? null : _stop,
                icon: const Icon(Icons.stop_circle),
                label: Text(l.formCheckStop),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.frost, foregroundColor: AppColors.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlacementGuide extends StatelessWidget {
  const _PlacementGuide({required this.l, required this.freeTry, required this.onStart});
  final AppLocalizations l;
  final bool freeTry;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(color: Colors.white70, fontSize: 14);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.accessibility_new, size: 96, color: Colors.white54),
          const SizedBox(height: AppSpacing.base),
          Text(l.formCheckPlacementTitle,
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: AppSpacing.sm),
          Text(l.formCheckPlacementInstructions, textAlign: TextAlign.center, style: body),
          const SizedBox(height: AppSpacing.base),
          Text(l.formCheckPrivacy, textAlign: TextAlign.center, style: body),
          const SizedBox(height: AppSpacing.sm),
          Text(l.formCheckBetaNote, textAlign: TextAlign.center, style: body),
          if (freeTry) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l.formCheckFreeTryNote, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.glacier)),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.minTapTarget,
            child: ElevatedButton(onPressed: onStart, child: Text(l.formCheckStartButton)),
          ),
        ],
      ),
    );
  }
}

class _CueChips extends StatelessWidget {
  const _CueChips({required this.cues, required this.language, required this.adjustLighting});
  final List<FormCue> cues;
  final String language;
  final String adjustLighting;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final cue in cues)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cue.key == 'adjust_lighting'
                    ? AppColors.steel.withValues(alpha: 0.92)
                    : (cue.severity == CueSeverity.error ? AppColors.frost : AppColors.glacier).withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cue.key == 'adjust_lighting' ? adjustLighting : (language == 'fr' ? cue.textFr : cue.textEn),
                style: TextStyle(
                  color: cue.key == 'adjust_lighting' ? AppColors.frost : AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      );
}

class _RepBadge extends StatelessWidget {
  const _RepBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration:
            BoxDecoration(color: AppColors.glacier.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(24)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      );
}
