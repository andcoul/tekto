import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import '../../core/theme/app_theme.dart';

/// Countdown rest timer.
/// Large readable digits — gym-proof (Principle VI).
/// Haptic + audible alert at 0.
class RestTimerWidget extends StatefulWidget {
  const RestTimerWidget({
    super.key,
    required this.seconds,
    required this.onSkip,
  });

  final int seconds;
  final VoidCallback onSkip;

  @override
  State<RestTimerWidget> createState() => _RestTimerWidgetState();
}

class _RestTimerWidgetState extends State<RestTimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    )..forward().whenComplete(_onComplete);
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _onComplete() async {
    await Haptics.vibrate(HapticsType.medium);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Rest',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.onDarkSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) => CircularProgressIndicator(
                        value: 1 - _progressController.value,
                        strokeWidth: 8,
                        backgroundColor: AppColors.charcoalElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) {
                        final remaining = ((1 - _progressController.value) *
                                widget.seconds)
                            .ceil();
                        return Text(
                          '$remaining',
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(fontSize: 72),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: AppSizes.minTapTarget,
                child: TextButton(
                  onPressed: widget.onSkip,
                  child: Text(
                    'Skip rest',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.onDarkSecondary,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
