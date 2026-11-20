import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../features/coach/ui/coach_launcher.dart';

/// The four top-level tabs, in display order.
enum TektoTab {
  home('/home', 'home', Icons.home_outlined, Icons.home_rounded),
  plan('/plan', 'plan_overview', Icons.fitness_center_outlined, Icons.fitness_center),
  library('/library', 'library', Icons.grid_view_outlined, Icons.grid_view_rounded),
  progress('/progress', 'progress', Icons.bar_chart_outlined, Icons.bar_chart_rounded);

  const TektoTab(this.path, this.coachScreen, this.icon, this.activeIcon);
  final String path;

  /// Screen name sent to the coach as `context.screen` (see CoachButton).
  final String coachScreen;
  final IconData icon;
  final IconData activeIcon;

  String label(AppLocalizations l) => switch (this) {
        TektoTab.home => l.navHome,
        TektoTab.plan => l.navPlan,
        TektoTab.library => l.navLibrary,
        TektoTab.progress => l.navProgress,
      };

  /// The tab whose root screen is [location], or null on any deeper screen
  /// (an exercise detail, for example), where the bar is hidden.
  static TektoTab? forLocation(String location) {
    for (final t in values) {
      if (location == t.path) return t;
    }
    return null;
  }
}

/// Wraps the main screens: the screen fills the page and the floating tab bar
/// sits over its bottom edge (design: frosted pill + round coach button).
/// Screens that use SafeArea keep their last row clear of the bar, because the
/// bar's height is added to the bottom padding they see.
class TabShell extends StatelessWidget {
  const TabShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const double barHeight = 64;
  static const double barGap = 12;

  @override
  Widget build(BuildContext context) {
    final active = TektoTab.forLocation(location);
    if (active == null) return child;
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    final reserved = barHeight + barGap + (bottomInset > 0 ? 0 : barGap);
    return Stack(
      children: [
        MediaQuery(
          data: media.copyWith(padding: media.padding.copyWith(bottom: bottomInset + reserved)),
          child: child,
        ),
        Positioned(
          left: AppSpacing.base,
          right: AppSpacing.base,
          bottom: (bottomInset > 0 ? bottomInset : barGap),
          child: TektoTabBar(active: active),
        ),
      ],
    );
  }
}

class TektoTabBar extends StatelessWidget {
  const TektoTabBar({super.key, required this.active});

  final TektoTab active;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: TabShell.barHeight,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TabShell.barHeight / 2),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: (dark ? AppColors.deep : AppColors.lightSurface).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(TabShell.barHeight / 2),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (final t in TektoTab.values)
                        _TabButton(
                          tab: t,
                          label: t.label(l),
                          selected: t == active,
                          onTap: () => context.go(t.path),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Semantics(
            button: true,
            label: l.homeCoach,
            child: Material(
              color: scheme.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => openCoach(context, screen: active.coachScreen),
                child: SizedBox.square(
                  dimension: TabShell.barHeight,
                  child: Icon(Icons.chat_bubble_outline_rounded, color: scheme.onPrimary, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.label, required this.selected, required this.onTap});

  final TektoTab tab;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: selected ? null : onTap,
        radius: 32,
        child: SizedBox(
          width: 64,
          height: TabShell.barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? tab.activeIcon : tab.icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(fontFamily: AppFonts.ui, fontSize: 10.5, fontWeight: FontWeight.w500, color: color),
              ),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
