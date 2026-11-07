import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/design.dart';
import 'data/credentials_store.dart';
import 'data/notifications.dart';
import 'data/portfolio_store.dart';
import 'data/remote_sync.dart';
import 'data/sync.dart';
import 'data/sync_outbox.dart';
import 'presentation/app.dart';
import 'presentation/onboarding_screens.dart';
import 'presentation/online_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final outbox = SyncOutbox();
  final store = PortfolioStore(outbox: outbox);
  final NotificationScheduler scheduler =
      kIsWeb ? NoopNotificationScheduler() : LocalNotificationScheduler();
  final credentials = CredentialsStore();
  final backendBase = Uri.tryParse(
    const String.fromEnvironment('LONYOGANG_BACKEND_URL', defaultValue: ''),
  );
  final SyncService sync = backendBase == null || backendBase.toString().isEmpty
      ? NoopSyncService()
      : RemoteSyncService(
          baseUri: backendBase,
          credentialsLoader: credentials.load,
          credentialsSaver: credentials.save,
          outboxLoader: outbox.snapshot,
          pullHandler: (_) async {
            // Pull handler is a hook for a future reducer that decrypts an
            // incoming event and merges it into the store. The current build
            // stores ciphertext and only re-plays its own writes.
          },
        );
  runApp(LonyoGangApp(
    store: store,
    scheduler: scheduler,
    sync: sync,
    credentials: credentials,
  ));
}

/// Root MaterialApp. Displays [SplashScreen] while the portfolio loads on
/// first launch; thereafter renders [AppRoot], which gates on vault lock
/// state and onboarding completion. Tests can inject a pre-loaded store or
/// shorten the splash via [splashDuration].
class LonyoGangApp extends StatefulWidget {
  final PortfolioStore store;
  final NotificationScheduler? scheduler;
  final SyncService? sync;
  final CredentialsStore? credentials;
  final Duration? splashDuration;
  const LonyoGangApp(
      {super.key,
      required this.store,
      this.scheduler,
      this.sync,
      this.credentials,
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
  Widget build(BuildContext context) {
    final syncService = widget.sync;
    final remote = syncService is RemoteSyncService ? syncService : null;
    return OnlineScope(
      sync: remote,
      credentials: widget.credentials ?? CredentialsStore(),
      child: MaterialApp(
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
      ),
    );
  }
}
