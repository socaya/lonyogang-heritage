import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppearanceController extends ChangeNotifier {
  static const preferenceKey='lonyogang_appearance_v1';
  ThemeMode _mode=ThemeMode.light;
  ThemeMode get mode=>_mode;
  Future<void> load() async {
    final prefs=await SharedPreferences.getInstance();
    final saved=prefs.getString(preferenceKey);
    _mode=ThemeMode.values.firstWhere((m)=>m.name==saved,orElse:()=>ThemeMode.light);
    notifyListeners();
  }
  Future<void> setMode(ThemeMode value) async {
    final prefs=await SharedPreferences.getInstance();
    if(!await prefs.setString(preferenceKey,value.name))throw StateError('Could not save appearance');
    _mode=value;
    notifyListeners();
  }
}
class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({super.key,required AppearanceController controller,required super.child}):super(notifier:controller);
  static AppearanceController? maybeOf(BuildContext context)=>context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
}
