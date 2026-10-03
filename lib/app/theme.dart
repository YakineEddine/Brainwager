// Design system Brainwager : violet électrique, jaune or, turquoise. Dark-first.
// Phase UI-1 : échelle typographique, thèmes boutons/cartes/chips/champs,
// AppBar et états pensés "party game premium" (hiérarchie forte, CTA visibles).
// Les couleurs de marque restent identiques ; seule l'application s'étoffe.
import 'package:flutter/material.dart';

import 'design_tokens.dart';

class BrainColors {
  static const electricViolet = Color(0xFF7C3AED);
  static const electricVioletDeep = Color(0xFF5B21B6);
  static const deepBackground = Color(0xFF1E1B2E);
  static const deepBackgroundTop = Color(0xFF2B2350);
  static const surface = Color(0xFF2A2542);
  static const surfaceHigh = Color(0xFF352C5C);
  static const outline = Color(0xFF4C4480);
  static const gold = Color(0xFFFFC93C);
  static const goldDeep = Color(0xFFB98600);
  static const turquoise = Color(0xFF2DD4BF);
  static const coral = Color(0xFFFF6B6B);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB8B3CC);
}

ThemeData buildBrainTheme() {
  final scheme = const ColorScheme.dark(
    primary: BrainColors.electricViolet,
    onPrimary: BrainColors.textPrimary,
    secondary: BrainColors.gold,
    onSecondary: Color(0xFF1E1B2E),
    tertiary: BrainColors.turquoise,
    error: BrainColors.coral,
    surface: BrainColors.surface,
    onSurface: BrainColors.textPrimary,
    surfaceContainerHighest: BrainColors.surfaceHigh,
    outline: BrainColors.outline,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: BrainColors.deepBackground,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: BrainColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: BrainColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: BrainColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: BrainColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: BrainColors.textSecondary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: BrainColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: BrainColors.textSecondary),
      bodySmall: TextStyle(fontSize: 12, color: BrainColors.textSecondary),
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: BrainColors.textPrimary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: BrainColors.textPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(BrainSpacing.xxl + 8),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrainRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(BrainSpacing.xxl),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        side: const BorderSide(color: BrainColors.outline, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrainRadius.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrainRadius.sm),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: BrainColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrainRadius.lg),
        side: const BorderSide(color: BrainColors.outline, width: 1),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: BrainColors.surfaceHigh,
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: BrainColors.textPrimary,
      ),
      side: const BorderSide(color: BrainColors.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrainRadius.pill),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: BrainColors.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: BrainSpacing.md,
        vertical: BrainSpacing.sm + 4,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrainRadius.md),
        borderSide: const BorderSide(color: BrainColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrainRadius.md),
        borderSide: const BorderSide(color: BrainColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BrainRadius.md),
        borderSide: const BorderSide(
          color: BrainColors.electricViolet,
          width: 2,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: BrainColors.outline,
      thickness: 1,
      space: BrainSpacing.md,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: BrainColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: BrainColors.textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrainRadius.md),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BrainColors.gold,
    ),
  );
}
