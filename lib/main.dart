import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'data/vault_repository.dart';
import 'state/wealth_store.dart';
import 'ui/auth.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: LG.canvas,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const LonyoGangApp());
}

class LonyoGangApp extends StatefulWidget {
  const LonyoGangApp({super.key});
  @override
  State<LonyoGangApp> createState() => _LonyoGangAppState();
}

class _LonyoGangAppState extends State<LonyoGangApp> {
  late final WealthStore store = WealthStore(VaultRepository())..initialize();

  @override
  void dispose() { store.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LonyoGang Heritage',
    debugShowCheckedModeBanner: false,
    theme: LG.light,
    home: AnimatedBuilder(animation: store,
      builder: (context, _) {
        if (store.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (store.lastError != null) {
          return Scaffold(body: SafeArea(child: Center(child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text(store.lastError!, textAlign: TextAlign.center)))));
        }
        if (!store.enrolled) return WelcomeScreen(store: store);
        if (!store.unlocked) return UnlockScreen(store: store);
        return MainShell(store: store);
      }),
  );
}
