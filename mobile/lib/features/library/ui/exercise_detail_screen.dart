import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/video_player_widget.dart';
import '../domain/exercise_provider.dart';

class ExerciseDetailScreen extends ConsumerStatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseSlug});
  final String exerciseSlug;

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState
    extends ConsumerState<ExerciseDetailScreen> {
  bool _showSideView = false;

  @override
  Widget build(BuildContext context) {
    final exerciseAsync = ref.watch(
      // Re-use exercise provider filtered to single slug
      exercisesProvider.selectAsync(
        (all) => all.where((e) => e.slug == widget.exerciseSlug).firstOrNull,
      ),
    );

    return Scaffold(
      body: exerciseAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (exercise) {
          if (exercise == null) {
            return const Center(child: Text('Exercise not found.'));
          }

          final videoUrl = _showSideView
              ? (exercise.videoSideUrl ?? exercise.videoFrontUrl)
              : exercise.videoFrontUrl;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: VideoPlayerWidget(
                    remoteUrl: videoUrl,
                    isPro: true, // library browsing shows video regardless
                    autoPlay: true,
                    looping: true,
                  ),
                ),
                actions: [
                  if (exercise.videoSideUrl != null)
                    TextButton(
                      onPressed: () =>
                          setState(() => _showSideView = !_showSideView),
                      child: Text(
                        _showSideView ? 'Front' : 'Side',
                        style: const TextStyle(color: AppColors.accent),
                      ),
                    ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.base),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      exercise.nameEn,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exercise.musclePrimary.join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader('Technique cues'),
                    ...exercise.cuesEn.asMap().entries.map(
                          (e) => _CueRow(number: e.key + 1, text: e.value),
                        ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionHeader('Common mistakes'),
                    ...exercise.commonMistakesEn
                        .map((m) => _MistakeRow(text: m)),
                    if (exercise.variationEasierSlug != null ||
                        exercise.variationHarderSlug != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _SectionHeader('Variations'),
                      if (exercise.variationEasierSlug != null)
                        _VariationTile(
                          slug: exercise.variationEasierSlug!,
                          label: 'Easier',
                          icon: Icons.arrow_downward,
                        ),
                      if (exercise.variationHarderSlug != null)
                        _VariationTile(
                          slug: exercise.variationHarderSlug!,
                          label: 'Harder',
                          icon: Icons.arrow_upward,
                        ),
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
