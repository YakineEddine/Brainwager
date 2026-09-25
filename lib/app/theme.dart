// Design system Brainwager : violet électrique, jaune or, turquoise. Dark-first.
// Mascotte + jetons dessinés en SVG maison (assets/logo/).
import 'package:flutter/material.dart';

class BrainColors {
  static const electricViolet = Color(0xFF7C3AED);
  static const deepBackground = Color(0xFF1E1B2E);
  static const surface = Color(0xFF2A2542);
  static const gold = Color(0xFFFFC93C);
  static const turquoise = Color(0xFF2DD4BF);
  static const coral = Color(0xFFFF6B6B);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB8B3CC);
}

ThemeData buildBrainTheme() {
  final scheme = const ColorScheme.dark(
    primary: BrainColors.electricViolet,
    secondary: BrainColors.gold,
    tertiary: BrainColors.turquoise,
    error: BrainColors.coral,
    surface: BrainColors.surface,
  ).copyWith(surface: BrainColors.surface);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BrainColors.deepBackground,
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}
