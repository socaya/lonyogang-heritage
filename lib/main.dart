import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/design.dart';
import 'data/notifications.dart';
import 'data/portfolio_store.dart';
import 'domain/models.dart';
import 'presentation/app.dart';
import 'presentation/onboarding_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = PortfolioStore();
  final NotificationScheduler scheduler =
      kIsWeb ? NoopNotificationScheduler() : LocalNotificationScheduler();
  runApp(LonyoGangApp(store: store, scheduler: scheduler));
}

/// Root MaterialApp. Displays [SplashScreen] while the portfolio loads on
/// first launch; thereafter renders [AppRoot], which gates on vault lock
/// state and onboarding completion. Tests can inject a pre-loaded store or
/// shorten the splash via [splashDuration].
class LonyoGangApp extends StatefulWidget {
  final PortfolioStore store;
  final NotificationScheduler? scheduler;
  final Duration? splashDuration;
  const LonyoGangApp(
      {super.key,
      required this.store,
      this.scheduler,
      this.splashDuration});
  @override
  State<LonyoGangApp> createState() => _LonyoGangAppState();
}

class _LonyoGangAppState extends State<LonyoGangApp> {
  bool _schedulerReady = false;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_syncScheduler);
  }

  @override
  void dispose() {
    widget.store.removeListener(_syncScheduler);
    super.dispose();
  }

  Future<void> _syncScheduler() async {
    final scheduler = widget.scheduler;
    if (scheduler == null || !_schedulerReady) return;
    try {
      await scheduler.syncWith(
          computeScheduledAlerts(widget.store.state, DateTime.now()));
    } catch (_) {
      // Platform channel may not be available (tests, unsupported devices).
    }
  }

  Future<void> _primeScheduler() async {
    final scheduler = widget.scheduler;
    if (scheduler == null) return;
    try {
      await scheduler.initialize();
      _schedulerReady = true;
      await _syncScheduler();
    } catch (e) {
      debugPrint('Notification scheduler unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LonyoGang Heritage',
        debugShowCheckedModeBanner: false,
        theme: LG.theme,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => NotFoundScreen(attemptedTarget: settings.name)),
        home: widget.store.isLoaded
            ? AppRoot(store: widget.store)
            : SplashScreen(
                store: widget.store,
                minimumVisible:
                    widget.splashDuration ?? const Duration(milliseconds: 650),
                onReady: (context) async {
                  await _primeScheduler();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                      builder: (_) => AppRoot(store: widget.store)));
                },
              ),
      );
}
