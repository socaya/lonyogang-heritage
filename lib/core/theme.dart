import 'package:flutter/material.dart';

/// The approved Theme 1 palette, not a generated material seed palette.
abstract final class LG {
  static const navy = Color(0xFF102D40);
  static const navyDeep = Color(0xFF0D283A);
  static const gold = Color(0xFFB88C3D);
  static const sage = Color(0xFF607E68);
  static const sageDark = Color(0xFF446B55);
  static const sageSoft = Color(0xFFE8F0E9);
  static const canvas = Color(0xFFF7F9F7);
  static const white = Colors.white;
  static const surface = Color(0xFFF0F4F1);
  static const line = Color(0xFFE1E8E3);
  static const ink = Color(0xFF163246);
  static const muted = Color(0xFF6F808A);
  static const danger = Color(0xFFAB5449);

  static const radius = 14.0;
  static const gutter = 24.0;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
    ).copyWith(
      primary: navy,
      onPrimary: white,
      secondary: sage,
      onSecondary: white,
      surface: canvas,
      onSurface: ink,
      error: danger,
      outline: line,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: navy,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: navy, fontSize: 30, height: 1.17, fontWeight: FontWeight.w800, letterSpacing: -0.8),
        headlineMedium: TextStyle(color: navy, fontSize: 25, height: 1.2, fontWeight: FontWeight.w750, letterSpacing: -0.6),
        titleLarge: TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: navy, fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: ink, fontSize: 16, height: 1.42),
        bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.42),
        bodySmall: TextStyle(color: muted, fontSize: 12, height: 1.35),
        labelLarge: TextStyle(fontSize: 14, color: navy, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: navy, foregroundColor: white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: sage, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radius), borderSide: const BorderSide(color: danger)),
        hintStyle: const TextStyle(color: muted),
      ),
      dividerColor: line,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navy,
        contentTextStyle: const TextStyle(color: white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
