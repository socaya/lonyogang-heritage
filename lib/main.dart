import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/design.dart';
import 'data/portfolio_store.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store=PortfolioStore();
  await store.load();
  runApp(LonyoGangApp(store:store));
}

class LonyoGangApp extends StatelessWidget {
  final PortfolioStore store;
  const LonyoGangApp({super.key,required this.store});
  @override Widget build(BuildContext context)=>MaterialApp(
    title:'LonyoGang Heritage',debugShowCheckedModeBanner:false,theme:LG.theme,
    home:AppRoot(store:store),
  );
}
