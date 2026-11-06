import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/design.dart';
import 'data/notifications.dart';
import 'data/portfolio_store.dart';
import 'domain/models.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = PortfolioStore();
  await store.load();
  final NotificationScheduler scheduler = kIsWeb
      ? NoopNotificationScheduler()
      : LocalNotificationScheduler();
  try {
    await scheduler.initialize();
    await _sync(scheduler, store.state);
    store.addListener(() => _sync(scheduler, store.state));
  } catch (e) {
    debugPrint('Notification scheduler unavailable: $e');
  }
  runApp(LonyoGangApp(store: store));
}

Future<void> _sync(NotificationScheduler scheduler, PortfolioState state) async {
  try {
    await scheduler.syncWith(computeScheduledAlerts(state, DateTime.now()));
  } catch (_) {
    // Platform channels may be absent (tests, unsupported devices).
  }
}

class LonyoGangApp extends StatelessWidget {
  final PortfolioStore store;
  const LonyoGangApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LonyoGang Heritage',
        debugShowCheckedModeBanner: false,
        theme: LG.theme,
        home: AppRoot(store: store),
      );
}
