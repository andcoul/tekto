import 'package:flutter/material.dart';

/// Tekto design tokens.
/// Dark-first (Principle VI); light theme follows system setting.
abstract final class AppColors {
  // Dark theme palette
  static const charcoalBase = Color(0xFF1A1A1A);
  static const charcoalSurface = Color(0xFF242424);
  static const charcoalElevated = Color(0xFF2E2E2E);
  static const accent = Color(0xFFFF6B2C);
  static const accentDim = Color(0xFFCC5522);
  static const onDark = Color(0xFFFFFFFF);
  static const onDarkSecondary = Color(0xFFB3B3B3);
  static const onDarkTertiary = Color(0xFF737373);
  static const error = Color(0xFFCF6679);
  static const success = Color(0xFF4CAF88);
  static const pr = Color(0xFFFFD700); // PR badge gold

  // Light theme palette
  static const lightBackground = Color(0xFFF5F5F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const onLight = Color(0xFF1A1A1A);
  static const onLightSecondary = Color(0xFF4A4A4A);
}

/// Spacing tokens (multiples of 4 dp).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Minimum tap target — 48×48 dp (Principle VI WCAG 2.1 AA).
abstract final class AppSizes {
  static const double minTapTarget = 48;
  static const double borderRadius = 12;
  static const double borderRadiusLg = 20;
  static const double cardElevation = 0;
}

abstract final class AppTheme {
  // ── Dark theme (default) ───────────────────────────────────────────────
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onDark,
      secondary: AppColors.charcoalElevated,
      onSecondary: AppColors.onDark,
      surface: AppColors.charcoalSurface,
      onSurface: AppColors.onDark,
      error: AppColors.error,
      onError: AppColors.onDark,
    ),
    scaffoldBackgroundColor: AppColors.charcoalBase,
    cardTheme: CardThemeData(
      elevation: AppSizes.cardElevation,
      color: AppColors.charcoalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.charcoalBase,
      foregroundColor: AppColors.onDark,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: _buildTextTheme(AppColors.onDark, AppColors.onDarkSecondary),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onDark,
        minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.charcoalElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
    ),
    dividerColor: AppColors.charcoalElevated,
    iconTheme: const IconThemeData(color: AppColors.onDarkSecondary),
  );

  // ── Light theme ────────────────────────────────────────────────────────
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: AppColors.onDark,
      secondary: Color(0xFFE8E8E8),
      onSecondary: AppColors.onLight,
      surface: AppColors.lightSurface,
      onSurface: AppColors.onLight,
      error: Color(0xFFB00020),
      onError: AppColors.onDark,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    cardTheme: CardThemeData(
      elevation: AppSizes.cardElevation,
      color: AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.onLight,
      elevation: 0,
      centerTitle: false,
    ),
    textTheme: _buildTextTheme(AppColors.onLight, AppColors.onLightSecondary),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onDark,
        minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        ),
      ),
    ),
    dividerColor: const Color(0xFFE0E0E0),
  );

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
