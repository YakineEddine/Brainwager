// Design system Brainwager : LIGHT-FIRST (ticket light-shell).
// Palette claire : fond cloud, surfaces blanches, teal/cobalt/corail.
// Les hexadécimaux de marque sombres ne dominent plus le chrome ;
// l'artwork approuvé (foncé) vit dans des surfaces hero dédiées.
// Mêmes noms de rôles (BrainColors) pour limiter la casse : les valeurs
// ont été remappées vers la sémantique claire (voir BrainRoles).
import 'package:flutter/material.dart';

import 'design_tokens.dart';

class BrainColors {
  // Primaire interactive : cobalt (sélection, CTA, liens).
  static const electricViolet = Color(0xFF3B82F6);
  static const electricVioletDeep = Color(0xFF2456C4);
  // Fonds : cloud + blanc.
  static const deepBackground = Color(0xFFF5FBFA);
  static const deepBackgroundTop = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFEAF4F3);
  static const outline = Color(0xFFD7E3E1);
  // Accents : or = détail premium/ranking uniquement.
  static const gold = Color(0xFFFFC93C);
  static const goldDeep = Color(0xFF8A6100);
  // Succès/positif : teal. Danger/critique : corail.
  static const turquoise = Color(0xFF00A7A0);
  static const tealDeep = Color(0xFF00776F);
  static const coral = Color(0xFFFF6B6B);
  static const textPrimary = Color(0xFF17324D);
  static const textSecondary = Color(0xFF6B7C8F);
}

ThemeData buildBrainTheme() {
  final scheme = const ColorScheme.light(
    primary: BrainColors.electricViolet,
    onPrimary: Colors.white,
    secondary: BrainColors.turquoise,
    onSecondary: Colors.white,
    tertiary: BrainColors.gold,
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
      iconTheme: IconThemeData(color: BrainColors.textPrimary),
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: BrainColors.textPrimary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BrainColors.electricViolet,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(BrainSpacing.xxl + 8),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrainRadius.md),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: BrainColors.electricVioletDeep,
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
        foregroundColor: BrainColors.electricVioletDeep,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrainRadius.sm),
        ),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: BrainColors.surface,
      elevation: 3,
      indicatorColor: Color(0x1A3B82F6),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: BrainColors.surface,
      elevation: 2,
      shadowColor: const Color(0x1A17324D),
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
      backgroundColor: BrainColors.textPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BrainRadius.md),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: BrainColors.turquoise,
    ),
  );
}
