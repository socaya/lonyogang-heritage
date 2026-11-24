import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LG {
  static const navy = Color(0xFF102D3F);
  static const navyDark = Color(0xFF0C2738);
  static const gold = Color(0xFFB58A3A);
  static const goldSoft = Color(0xFFF4EBD6);
  static const sage = Color(0xFF62816B);
  static const sageSoft = Color(0xFFEAF0EB);
  static const canvas = Color(0xFFF6F3EC);
  static const ivory = Color(0xFFF6F3EC);
  static const sageDark = Color(0xFF446B55);
  static const white = Colors.white;
  static const muted = Color(0xFF526570);
  static const line = Color(0xFFDEDED4);
  static const negative = Color(0xFFAB4E46);
  static const r = 12.0;
  static const hPad = 20.0;

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
                fontSize: 34, fontFeatures: [FontFeature.tabularFigures()], fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -1.0, color: navy),
            headlineMedium: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w700, height: 1.14, letterSpacing: -.8, color: navy),
            headlineSmall: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -.4, color: navy),
            titleLarge: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.3, color: navy),
            titleMedium: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w600, color: navy),
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
              fontWeight: FontWeight.w700,
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
              const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          hintStyle: const TextStyle(color: Color(0xFF526570), fontSize: 15),
          labelStyle: const TextStyle(
              color: muted, fontSize: 15, fontWeight: FontWeight.w600),
          floatingLabelStyle: const TextStyle(
              color: navy, fontSize: 13, fontWeight: FontWeight.w700),
          border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: line, width: 1),
              borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: gold, width: 1.6),
              borderRadius: BorderRadius.circular(8)),
          errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: negative, width: 1.2),
              borderRadius: BorderRadius.circular(8)),
          focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: negative, width: 1.6),
              borderRadius: BorderRadius.circular(8))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: navy,
              foregroundColor: white,
              elevation: 0,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .1))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: navy,
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: line, width: 1.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: navy,
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700))),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: navy,
          indicatorColor: Colors.transparent,
          elevation: 0,
          height: 68,
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? const Color(0xFFE5C27F) : Colors.white,
            size: 24,
          )),
          labelTextStyle: WidgetStateProperty.all(const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: white))),
      dividerTheme: const DividerThemeData(color: line, space: 1, thickness: 1),
      snackBarTheme: SnackBarThemeData(
          backgroundColor: navy,
          contentTextStyle: const TextStyle(color: white, fontSize: 14),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12))),
    );
  }
  static bool isDark(BuildContext context)=>Theme.of(context).brightness==Brightness.dark;
  static const darkCanvas=Color(0xFF142F40);
  static const darkSurface=Color(0xFF1B394A);
  static const darkInk=Color(0xFFF6F3EC);
  static const darkMuted=Color(0xFFB9C8CB);
  static const darkLine=Color(0xFF395464);
  static const darkGold=Color(0xFFE5C27F);
  static const darkSage=Color(0xFFABC9B4);
  static const darkSageSoft=Color(0xFF24463E);
  static const darkNegative=Color(0xFFF1A29B);

  /// Map semantic light roles; explicitly branded hero colors stay fixed.
  static Color adaptive(BuildContext context,Color color) {
    if(!isDark(context))return color;
    if(color==canvas)return darkCanvas;
    if(color==white)return darkSurface;
    if(color==muted)return darkMuted;
    if(color==line)return darkLine;
    if(color==sageSoft)return darkSageSoft;
    if(color==goldSoft)return const Color(0xFF51432C);
    if(color==sage||color==sageDark)return darkSage;
    if(color==negative)return darkNegative;
    if(color==gold)return darkGold;
    if(color==navy)return darkInk;
    if(color==const Color(0xFFF8EAE7))return const Color(0xFF533438);
    if(color==const Color(0xFFFBF3DD))return const Color(0xFF51432C);
    if(color==const Color(0xFF8C6A1D))return darkGold;
    return color;
  }
  static Color surface(BuildContext context,Color color)=>
      color==navy||color==navyDark ? color : adaptive(context,color);
  static ThemeData get darkTheme {
    final light=theme;
    final base=ThemeData(useMaterial3:true,brightness:Brightness.dark);
    final scheme=ColorScheme.fromSeed(seedColor:navy,brightness:Brightness.dark,
      primary:darkGold,onPrimary:navy,secondary:darkSage,onSecondary:navyDark,
      surface:darkSurface,onSurface:darkInk,onSurfaceVariant:darkMuted,
      outline:darkLine,outlineVariant:darkLine,error:darkNegative);
    return base.copyWith(
      colorScheme:scheme,scaffoldBackgroundColor:darkCanvas,
      textTheme:light.textTheme.apply(bodyColor:darkInk,displayColor:darkInk).copyWith(
        bodySmall:light.textTheme.bodySmall?.copyWith(color:darkMuted)),
      appBarTheme:light.appBarTheme.copyWith(backgroundColor:darkCanvas,foregroundColor:darkInk,titleTextStyle:light.appBarTheme.titleTextStyle?.copyWith(color:darkInk)),
      cardTheme:light.cardTheme.copyWith(color:darkSurface),
      inputDecorationTheme:light.inputDecorationTheme.copyWith(fillColor:darkSurface,
        hintStyle:const TextStyle(color:darkMuted,fontSize:15),
        labelStyle:const TextStyle(color:darkMuted,fontSize:15),
        floatingLabelStyle:const TextStyle(color:darkGold,fontSize:13),
        enabledBorder:OutlineInputBorder(borderSide:const BorderSide(color:darkLine),borderRadius:BorderRadius.circular(8)),
        focusedBorder:OutlineInputBorder(borderSide:const BorderSide(color:darkGold,width:1.6),borderRadius:BorderRadius.circular(8)),
        errorBorder:OutlineInputBorder(borderSide:const BorderSide(color:darkNegative),borderRadius:BorderRadius.circular(8)),
        focusedErrorBorder:OutlineInputBorder(borderSide:const BorderSide(color:darkNegative,width:1.6),borderRadius:BorderRadius.circular(8))),
      elevatedButtonTheme:ElevatedButtonThemeData(style:ElevatedButton.styleFrom(backgroundColor:darkGold,foregroundColor:navy,minimumSize:const Size.fromHeight(52),elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)))),
      outlinedButtonTheme:OutlinedButtonThemeData(style:OutlinedButton.styleFrom(foregroundColor:darkInk,side:const BorderSide(color:darkLine),minimumSize:const Size.fromHeight(52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)))),
      textButtonTheme:TextButtonThemeData(style:TextButton.styleFrom(foregroundColor:darkGold)),
      navigationBarTheme:light.navigationBarTheme.copyWith(backgroundColor:navyDark),
      dividerTheme:const DividerThemeData(color:darkLine,space:1,thickness:1),
      snackBarTheme:light.snackBarTheme,
      bottomSheetTheme:const BottomSheetThemeData(backgroundColor:darkSurface),
    );
  }

  static String money(int amount,{bool compact=false}) {
    if(compact && amount.abs()>=1000000000) return 'UGX ${(amount/1000000000).toStringAsFixed(2)}B';
    if(compact && amount.abs()>=1000000)return 'UGX ${(amount/1000000).toStringAsFixed(1)}M';
    return 'UGX ${NumberFormat('#,##0').format(amount)}';
  }
  static String date(DateTime date)=>DateFormat('dd MMM yyyy').format(date);
}
