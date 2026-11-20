import 'package:flutter/material.dart';

/// Tekto design tokens: "Midnight & Glacier" (design/README.md).
/// Dark-first (Constitution VI); the light theme follows the system setting.
/// Glacier is the action colour. Mint is kept for records and success only.
/// No yellow anywhere.
abstract final class AppColors {
  // ── Dark palette ──────────────────────────────────────────────────────
  static const night = Color(0xFF0F1014); // background
  static const mid = Color(0xFF16171D); // cards, sheets
  static const deep = Color(0xFF1F2129); // inputs, raised rows
  static const steel = Color(0xFF2A2D37); // chips, tracks, dividers
  static const line = Color(0xFF3A3E4B); // borders
  static const frost = Color(0xFFEEF0F5); // primary text
  static const mist = Color(0xFFA2A7B6); // secondary text
  static const glacier = Color(0xFF9DB8FF); // actions, selection
  static const mint = Color(0xFF7EE0B8); // records, success
  static const ink = Color(0xFF0B0D12); // text on glacier / mint
  static const danger = Color(0xFFFF8F8F); // destructive actions only

  // ── Light palette ─────────────────────────────────────────────────────
  static const lightBackground = Color(0xFFF4F5F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightRaised = Color(0xFFE9EBF1);
  static const onLight = Color(0xFF14161C);
  static const onLightSecondary = Color(0xFF5A6070);
  static const glacierDeep = Color(0xFF3D5BD9); // glacier with contrast on white
  static const dangerDeep = Color(0xFFC23B3B);
}

/// Font families bundled in assets/fonts (pubspec.yaml).
abstract final class AppFonts {
  static const display = 'BricolageGrotesque'; // titles; ExtraBold caps over photos
  static const ui = 'Geist'; // interface text and numbers
  static const mono = 'GeistMono'; // small uppercase labels
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

/// Minimum tap target 48×48 dp (Constitution VI, WCAG 2.1 AA).
abstract final class AppSizes {
  static const double minTapTarget = 48;
  static const double buttonHeight = 56; // pill buttons
  static const double borderRadius = 16;
  static const double borderRadiusLg = 24;
  static const double cardElevation = 0;
}

/// Ready-made text styles for the few places that need the display face or
/// the mono label directly (theme text styles cover the rest).
abstract final class AppText {
  /// Big uppercase title, e.g. "LOWER A" on a photo.
  static const hero = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 44,
    height: 0.95,
    letterSpacing: -0.4,
  );

  /// Huge numbers in the live session (load, reps).
  static const bigNumber = TextStyle(
    fontFamily: AppFonts.display,
    fontWeight: FontWeight.w800,
    fontSize: 88,
    height: 0.9,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Small uppercase label, e.g. "SET 2 OF 4".
  static const label = TextStyle(
    fontFamily: AppFonts.mono,
    fontWeight: FontWeight.w500,
    fontSize: 11,
    letterSpacing: 1.1,
  );
}

abstract final class AppTheme {
  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    background: AppColors.night,
    surface: AppColors.mid,
    raised: AppColors.deep,
    border: AppColors.steel,
    text: AppColors.frost,
    textSecondary: AppColors.mist,
    primary: AppColors.glacier,
    onPrimary: AppColors.ink,
    error: AppColors.danger,
  );

  static final ThemeData light = _build(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    raised: AppColors.lightRaised,
    border: const Color(0xFFDADDE6),
    text: AppColors.onLight,
    textSecondary: AppColors.onLightSecondary,
    primary: AppColors.glacierDeep,
    onPrimary: Colors.white,
    error: AppColors.dangerDeep,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color raised,
    required Color border,
    required Color text,
    required Color textSecondary,
    required Color primary,
    required Color onPrimary,
    required Color error,
  }) {
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.buttonHeight / 2),
    );
    const buttonText = TextStyle(
      fontFamily: AppFonts.ui,
      fontWeight: FontWeight.w600,
      fontSize: 17,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppFonts.ui,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        secondary: raised,
        onSecondary: text,
        tertiary: AppColors.mint,
        onTertiary: AppColors.ink,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: textSecondary,
        surfaceContainerHighest: raised,
        outline: border,
        outlineVariant: border,
        error: error,
        onError: brightness == Brightness.dark ? AppColors.ink : Colors.white,
      ),
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardTheme: CardThemeData(
        elevation: AppSizes.cardElevation,
        color: surface,
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.ui,
          fontWeight: FontWeight.w600,
          fontSize: 17,
          color: text,
        ),
      ),
      textTheme: _buildTextTheme(text, textSecondary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
          textStyle: buttonText.copyWith(fontSize: 15),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: primary,
        labelStyle: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w500, fontSize: 14, color: text),
        secondaryLabelStyle:
            TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w500, fontSize: 14, color: onPrimary),
        checkmarkColor: onPrimary,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onPrimary : text,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
        circularTrackColor: border,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: raised,
        contentTextStyle: TextStyle(fontFamily: AppFonts.ui, color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadius)),
      ),
      listTileTheme: ListTileThemeData(iconColor: textSecondary),
      dividerColor: border,
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      iconTheme: IconThemeData(color: textSecondary),
    );
  }

  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    TextStyle display(double size) => TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w800,
          fontSize: size,
          height: 1.0,
          color: primary,
        );
    TextStyle heading(double size) => TextStyle(
          fontFamily: AppFonts.display,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1.15,
          color: primary,
        );
    TextStyle ui(double size, FontWeight w, Color c) =>
        TextStyle(fontFamily: AppFonts.ui, fontSize: size, fontWeight: w, color: c);
    return TextTheme(
      displayLarge: display(44),
      displayMedium: display(36),
      displaySmall: display(30),
      headlineLarge: heading(28),
      headlineMedium: heading(24),
      headlineSmall: heading(20),
      titleLarge: ui(18, FontWeight.w600, primary),
      titleMedium: ui(16, FontWeight.w600, primary),
      titleSmall: ui(14, FontWeight.w600, primary),
      bodyLarge: ui(16, FontWeight.w400, primary),
      bodyMedium: ui(14, FontWeight.w400, secondary),
      bodySmall: ui(12.5, FontWeight.w400, secondary),
      labelLarge: ui(15, FontWeight.w600, primary),
      labelMedium: AppText.label.copyWith(color: secondary, fontSize: 12),
      labelSmall: AppText.label.copyWith(color: secondary),
    );
  }
}
