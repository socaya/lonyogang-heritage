import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LG {
  static const navy = Color(0xFF102D3F);
  static const navyDark = Color(0xFF0C2738);
  static const gold = Color(0xFFB58A3A);
  static const goldSoft = Color(0xFFF4EBD6);
  static const sage = Color(0xFF62816B);
  static const sageSoft = Color(0xFFEAF0EB);
  static const canvas = Color(0xFFF7F9F7);
  static const white = Colors.white;
  static const muted = Color(0xFF6C7D86);
  static const line = Color(0xFFE5EAE7);
  static const negative = Color(0xFFAB4E46);
  static const r = 16.0;
  static const hPad = 24.0;

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
          seedColor: navy, primary: navy, secondary: gold, surface: white),
      textTheme: base.textTheme.apply(bodyColor: navy, displayColor: navy).copyWith(
            // Modern & professional scale: bigger hierarchy, generous
            // line-height, tightened tracking on display styles.
            displaySmall: const TextStyle(
                fontSize: 34, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -1.0, color: navy),
            headlineMedium: const TextStyle(
                fontSize: 30, fontWeight: FontWeight.w800, height: 1.14, letterSpacing: -.8, color: navy),
            headlineSmall: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -.4, color: navy),
            titleLarge: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.3, color: navy),
            titleMedium: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: navy),
            titleSmall: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: navy),
            bodyLarge: const TextStyle(fontSize: 16, color: navy, height: 1.5),
            bodyMedium: const TextStyle(fontSize: 15, color: navy, height: 1.5),
            bodySmall: const TextStyle(fontSize: 13, color: muted, height: 1.5),
            labelLarge: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: navy),
          ),
      appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: navy,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: navy,
              letterSpacing: -.3)),
      cardTheme: const CardThemeData(
          color: white,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(r)))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          hintStyle: const TextStyle(color: Color(0xFF93A0A6), fontSize: 15),
          labelStyle: const TextStyle(
              color: muted, fontSize: 15, fontWeight: FontWeight.w600),
          floatingLabelStyle: const TextStyle(
              color: navy, fontSize: 13, fontWeight: FontWeight.w700),
          border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: line, width: 1),
              borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: gold, width: 1.6),
              borderRadius: BorderRadius.circular(14)),
          errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: negative, width: 1.2),
              borderRadius: BorderRadius.circular(14)),
          focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: negative, width: 1.6),
              borderRadius: BorderRadius.circular(14))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: navy,
              foregroundColor: white,
              elevation: 0,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .1))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: navy,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: line, width: 1.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: navy,
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700))),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: white,
          indicatorColor: goldSoft,
          height: 76,
          labelTextStyle: WidgetStateProperty.all(const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: navy))),
      dividerTheme: const DividerThemeData(color: line, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: navy,
          contentTextStyle: const TextStyle(color: white, fontSize: 14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12))),
    );
  }
  static String money(int amount,{bool compact=false}) {
    if(compact && amount.abs()>=1000000000) return 'UGX ${(amount/1000000000).toStringAsFixed(2)}B';
    if(compact && amount.abs()>=1000000)return 'UGX ${(amount/1000000).toStringAsFixed(1)}M';
    return 'UGX ${NumberFormat('#,##0').format(amount)}';
  }
  static String date(DateTime date)=>DateFormat('dd MMM yyyy').format(date);
}
