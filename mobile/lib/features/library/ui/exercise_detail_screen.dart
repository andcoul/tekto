import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../plan/domain/plan_provider.dart';
import '../../subscription/domain/entitlement_provider.dart';
import '../../../shared/widgets/video_player_widget.dart';
import '../domain/exercise_provider.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseSlug});
  final String exerciseSlug;

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  bool _showSideView = false;
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);
    final isPro = ref.watch(entitlementProvider).value?.isPro ?? false;
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final download = ref.watch(exerciseDownloadProvider(widget.exerciseSlug)).value;
    final l10n = AppLocalizations.of(context);
    final fr = Localizations.localeOf(context).languageCode == 'fr';

    return Scaffold(
      body: exercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorGeneric)),
        data: (all) {
          final exercise = all.where((e) => e.slug == widget.exerciseSlug).firstOrNull;
          if (exercise == null) return Center(child: Text(l10n.errorGeneric));

          final videoUrl = _showSideView ? (exercise.videoSideUrl ?? exercise.videoFrontUrl) : exercise.videoFrontUrl;
          final cues = fr ? exercise.cuesFr : exercise.cuesEn;
          final mistakes = fr ? exercise.commonMistakesFr : exercise.commonMistakesEn;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: VideoPlayerWidget(
                    isPro: isPro,
                    isOnline: isOnline,
                    remoteUrl: videoUrl,
                    // Downloads are front-angle only; the side view always streams.
                    localPath: _showSideView ? null : download?.localPath,
                    remoteCaptions: {
                      if (exercise.captionsEnUrl != null) 'en': exercise.captionsEnUrl!,
                      if (exercise.captionsFrUrl != null) 'fr': exercise.captionsFrUrl!,
                    },
                    localCaptions: download?.captions ?? const {},
                  ),
                ),
                actions: [
                  if (exercise.videoSideUrl != null)
                    TextButton(
                      onPressed: () => setState(() => _showSideView = !_showSideView),
                      child: Text(_showSideView ? 'Front' : 'Side', style: const TextStyle(color: AppColors.accent)),
                    ),
                  // Offline downloads are a Pro entitlement (FR-015); hidden for free users.
                  if (isPro)
                    IconButton(
                      tooltip: l10n.libraryDownloadForOffline,
                      onPressed: download != null || _downloading || !isOnline ? null : _downloadActivePlan,
                      icon: Icon(download != null ? Icons.download_done : Icons.download, color: AppColors.accent),
                    ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.base),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(fr ? exercise.nameFr : exercise.nameEn, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(exercise.musclePrimary.join(' · '), style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader(fr ? 'Consignes techniques' : 'Technique cues'),
                    ...cues.asMap().entries.map((e) => _CueRow(number: e.key + 1, text: e.value)),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader(fr ? 'Erreurs fréquentes' : 'Common mistakes'),
                    ...mistakes.map((m) => _MistakeRow(text: m)),
                    if (exercise.variationEasierSlug != null || exercise.variationHarderSlug != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _SectionHeader(fr ? 'Variantes' : 'Variations'),
                      if (exercise.variationEasierSlug != null)
                        _VariationTile(slug: exercise.variationEasierSlug!, label: fr ? 'Plus facile' : 'Easier', icon: Icons.arrow_downward),
                      if (exercise.variationHarderSlug != null)
                        _VariationTile(slug: exercise.variationHarderSlug!, label: fr ? 'Plus difficile' : 'Harder', icon: Icons.arrow_upward),
                    ],
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Downloads every video in the active plan (the contract is per plan, so this exercise is
  /// included when it is in the plan).
  Future<void> _downloadActivePlan() async {
    final plan = ref.read(activePlanProvider).value;
    if (plan == null) return;
    setState(() => _downloading = true);
    try {
      await ref.read(videoDownloadServiceProvider).downloadPlanVideos(plan.id, isPro: true).drain<void>();
      ref.invalidate(exerciseDownloadProvider);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).errorGeneric)));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _CueRow extends StatelessWidget {
  const _CueRow({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: AppColors.onDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _MistakeRow extends StatelessWidget {
  const _MistakeRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.close, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

class _VariationTile extends StatelessWidget {
  const _VariationTile({
    required this.slug,
    required this.label,
    required this.icon,
  });

  final String slug;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.accent),
        title: Text(label),
        subtitle: Text(slug, style: Theme.of(context).textTheme.bodyMedium),
        onTap: () => context.push('/library/$slug'),
      );
}
