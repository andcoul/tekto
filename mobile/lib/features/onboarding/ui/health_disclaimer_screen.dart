import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Unskippable health disclaimer — MUST be shown before the first plan is generated.
/// Constitution Principle III: Health disclaimer MUST be presented at onboarding and cannot be skipped.
class HealthDisclaimerScreen extends StatelessWidget {
  const HealthDisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              const Icon(
                Icons.health_and_safety_outlined,
                size: 56,
                color: AppColors.accent,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Before we start',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.base),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'Tekto provides AI-generated training plans for educational purposes '
                    'only. Always consult a qualified healthcare professional before '
                    'starting any exercise program, especially if you have a '
                    'pre-existing condition, injury, or health concern.\n\n'
                    'Stop exercising and seek medical advice if you experience pain, '
                    'dizziness, or unusual symptoms.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => context.go('/onboarding/quiz'),
                child: const Text("I understand — let's go"),
              ),
              // No "Skip" button — this screen cannot be skipped (Principle III).
            ],
          ),
        ),
      ),
    );
  }
}
