// Focus muscles (FR-052): premium muscle tiles, pick up to 2. Used in onboarding (after the
// equipment step) and in the profile editor.
import 'package:flutter/material.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/muscle_groups.dart';
import '../../../shared/widgets/muscle_figure.dart';

class FocusMusclesPicker extends StatelessWidget {
  const FocusMusclesPicker({super.key, required this.selected, required this.onToggle});
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final full = selected.length >= maxFocusMuscles;
    return ListView(
      children: [
        Text(l.quizFocusTitle, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(l.quizFocusBody, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l.quizFocusCount(selected.length), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.base),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.78,
          children: [
            for (final g in kMuscleGroups)
              _FocusTile(
                key: ValueKey('focus-$g'),
                label: muscleGroupLabel(g, lang),
                group: g,
                selected: selected.contains(g),
                dimmed: full && !selected.contains(g),
                onTap: () => onToggle(g),
              ),
          ],
        ),
      ],
    );
  }
}

class _FocusTile extends StatelessWidget {
  const _FocusTile({
    super.key,
    required this.label,
    required this.group,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });
  final String label;
  final String group;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Opacity(
            opacity: dimmed ? 0.45 : 1,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final size = c.biggest.shortestSide;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(size * 0.26),
                              border: Border.all(color: selected ? AppColors.glacier : Colors.transparent, width: 2),
                              boxShadow: selected
                                  ? [BoxShadow(color: AppColors.glacier.withValues(alpha: 0.35), blurRadius: 18)]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: MuscleTile(group: group, size: size - 8, level: selected ? 3 : 2),
                            ),
                          ),
                          if (selected)
                            const Positioned(
                              top: 6,
                              right: 6,
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: AppColors.glacier,
                                child: Icon(Icons.check, size: 14, color: AppColors.ink),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      );
}
