import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LG {
  static const navy=Color(0xFF102D3F);
  static const navyDark=Color(0xFF0C2738);
  static const gold=Color(0xFFB58A3A);
  static const sage=Color(0xFF62816B);
  static const sageSoft=Color(0xFFEAF0EB);
  static const canvas=Color(0xFFF7F9F7);
  static const white=Colors.white;
  static const muted=Color(0xFF6C7D86);
  static const line=Color(0xFFE5EAE7);
  static const negative=Color(0xFFAB4E46);
  static const r=14.0;
  static const hPad=24.0;

  static ThemeData get theme {
    final base=ThemeData(useMaterial3:true,brightness:Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor:canvas,
      colorScheme:ColorScheme.fromSeed(seedColor:navy,primary:navy,secondary:gold,surface:white),
      textTheme:base.textTheme.apply(bodyColor:navy,displayColor:navy).copyWith(
        headlineMedium:const TextStyle(fontSize:29,fontWeight:FontWeight.w800,height:1.12,letterSpacing:-.9,color:navy),
        titleLarge:const TextStyle(fontSize:20,fontWeight:FontWeight.w800,letterSpacing:-.4,color:navy),
        titleMedium:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:navy),
        bodyMedium:const TextStyle(fontSize:14,color:navy),
      ),
      appBarTheme:const AppBarTheme(backgroundColor:canvas,foregroundColor:navy,centerTitle:false,elevation:0,scrolledUnderElevation:0),
      cardTheme:const CardThemeData(color:white,shadowColor:Colors.transparent,surfaceTintColor:Colors.transparent,
        margin:EdgeInsets.zero,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(r)))),
      inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:white,contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:16),
        hintStyle:const TextStyle(color:Color(0xFF93A0A6),fontSize:14),
        border:OutlineInputBorder(borderSide:BorderSide.none,borderRadius:BorderRadius.circular(12)),
        enabledBorder:OutlineInputBorder(borderSide:const BorderSide(color:line,width:1),borderRadius:BorderRadius.circular(12)),
        focusedBorder:OutlineInputBorder(borderSide:const BorderSide(color:sage,width:1.4),borderRadius:BorderRadius.circular(12))),
      elevatedButtonTheme:ElevatedButtonThemeData(style:ElevatedButton.styleFrom(
        backgroundColor:navy,foregroundColor:white,elevation:0,minimumSize:const Size.fromHeight(52),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
        textStyle:const TextStyle(fontSize:16,fontWeight:FontWeight.w700))),
      navigationBarTheme:NavigationBarThemeData(backgroundColor:white,indicatorColor:sageSoft,height:72,
        labelTextStyle:WidgetStateProperty.all(const TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:navy))),
      dividerTheme:const DividerThemeData(color:line,space:1,thickness:1),
    );
  }
  static String money(int amount,{bool compact=false}) {
    if(compact && amount.abs()>=1000000000) return 'UGX ${(amount/1000000000).toStringAsFixed(2)}B';
    if(compact && amount.abs()>=1000000)return 'UGX ${(amount/1000000).toStringAsFixed(1)}M';
    return 'UGX ${NumberFormat('#,##0').format(amount)}';
  }
  static String date(DateTime date)=>DateFormat('dd MMM yyyy').format(date);
}
